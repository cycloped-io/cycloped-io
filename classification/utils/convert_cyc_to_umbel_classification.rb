#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
$:.unshift 'lib'
require 'slop'
require 'csv'
require 'cycr'
require 'progress'
$:.unshift '../category-mapping/lib'
require 'mapping/service/cyc_name_service'
require 'mapping/cyc_term'
require 'benchmark'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -c cyc_to_umbel.csv -i dbpedia_instances_to_cyc.csv -o output.csv\n" +
             'Converts Cyc terms to Umbel concepts.'

  on :c=, :cyc_to_umbel, 'Cyc to UMBEL mapping', required: true
  on :i=, :classification, 'Articles classification to Cyc', required: true
  on :o=, :output, 'Articles classification to UMBEL', required: true
  on :h=, :host, 'Cyc host (localhost)', default: 'localhost'
  on :p=, :port, 'Cyc port (3601)', as: Integer, default: 3601
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

cyc = Cyc::Client.new(host: options[:host], port: options[:port], cache: true)
name_service = Mapping::Service::CycNameService.new(cyc)


cyc_to_umbel=Hash.new
CSV.open(options[:cyc_to_umbel]) do |csv_cyc_to_umbel|
  csv_cyc_to_umbel.each do |cycid, umbel|
    cyc_to_umbel[cycid]=umbel
  end
end


stats = Hash.new(0)


CSV.open(options[:output], 'w') do |result|
  CSV.open(options[:classification]) do |csv_mapping|
    csv_mapping.with_progress do |name, *cycids|
      #p name, cycids
      # cyc_term_to_umbel(cycids, cyc_to_umbel, cyc, name_service)

      umbel_mappings = []

      cycids.each_slice(2) do |cycid, cyc_name|
        if cyc_to_umbel.include? cycid
          umbel_mappings.push cyc_to_umbel[cycid]
          # result << [name, cyc_to_umbel[cycid]]
=begin
        else
          # p cycid
          stats[cycid]+=1
          term =name_service.find_by_id(cycid)
          terms=[term]
          used = Set.new
          while not terms.empty?
            used.merge(terms)
            genls = terms.map { |term| cyc.min_genls(term) }.flatten.reject { |term| term==nil }.uniq
            genls.map! { |c| name_service.find_by_term_name(c.to_s) }
            genls = genls-used.to_a
            if genls.empty?
              p term
              break
            end
            #p genls
            umbels = genls.map { |term| cyc_to_umbel[term.id] }.reject { |umbel| umbel==nil }
            if not umbels.empty?
              # result << [name, *umbels]
              umbel_mappings.concat(umbels)
              break
            end
            terms=genls
          end
=end
        end
      end
      if !umbel_mappings.empty?
        result << [name, *(umbel_mappings.uniq)]
      end
    end
  end
end

stats.sort_by { |k, v| v }.reverse.each do |k, v|
  p k, v
end
