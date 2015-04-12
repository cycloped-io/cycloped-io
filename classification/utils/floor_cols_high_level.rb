#!/usr/bin/env ruby
# encding: utf-8

require 'bundler/setup'
$:.unshift "../category-mapping/lib"
require 'set'
require 'progress'
require 'csv'
require 'slop'
require 'cycr'
require 'mapping'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -f classification.csv -t types.csv -o new_classification.csv\n" +
             "for extension of upper ontology"

  on :f=, :input, "File with article classification", required: true
  on :o=, :output, "File with classification to high-level concepts", required: true
  on :t=, :types, "Cyc high-level concepts", required: true
  on :h=, :host, "Cyc host", default: "localhost"
  on :p=, :port, "Cyc port", as: Integer, default: 3601
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

def convert_array_to_cyc(array)
  -> { "'(" + array.map{|e| e.to_cyc(true) }.join(" ") + ')' }
end

cyc = Cyc::Client.new(cache: true, host: options[:host], port: options[:port])
name_service = Mapping::Service::CycNameService.new(cyc)

types = []
CSV.open(options[:types]) do |input|
  input.each do |row|
    types << name_service.find_by_term_name(row.first)
  end
end

types = convert_array_to_cyc(types)

CSV.open(options[:input]) do |input|
  CSV.open(options[:output],"w") do |output|
    input.with_progress do |article,cyc_id,cyc_name|
      begin
        term = name_service.find_by_id(cyc_id)
        tuple = [article]
        floor_cols = cyc.with_any_mt{|c| c. max_floor_cols(convert_array_to_cyc(cyc.all_genls_among(term,types))) }

        floor_cols2 =  floor_cols.select{|col| cyc.with_any_mt{|c| c.genls?(term,col)}}
        # what if more than one? repeat step?

        floor_cols2.each do |term|
          id = cyc.compact_hl_external_id_string(term)
          tuple << id << term
        end
        output << tuple
      rescue Interrupt
        break
      rescue
        puts "#{article} #{cyc_id} #{cyc_name}"
      end
    end
  end
end
