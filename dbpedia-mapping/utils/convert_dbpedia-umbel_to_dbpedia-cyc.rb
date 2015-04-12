#!/usr/bin/env ruby

require 'bundler/setup'
$:.unshift 'lib'
require 'slop'
require 'csv'
require 'progress'
require 'cycr'

$:.unshift '../category-mapping/lib'
require 'mapping/cyc_term'
require 'mapping/service/cyc_name_service'
require 'mapping/bidirectional_map'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -b sd_dbpedia_class_mapping_v2.csv -c umbel_to_cyc_mapping.csv -d manual_dbpedia_to_cyc_mapping.csv -o dbpedia_to_cyc.csv \n" +
             "Maps DBpedia mapping from UMBEL to Cyc."

  on :b=, :dbpedia_to_umbel, "File with DBpedia to UMBEL mapping; columns: 1. DBpedia class name, 2. UMBEL concept", required: true
  on :c=, :umbel_to_cyc, "File with UMBEL to Cyc mapping; columns: 1. UMBEL concept, 2. Cyc ID", required: true
  on :d=, :manual_dbpedia_to_cyc, "File with manual DBpedia to Cyc mapping; columns: 1. DBpedia class name, 2. Cyc term name", required: true
  on :o=, :output, "File with DBpedia to Cyc mapping", required: true
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

umbel_to_cyc = Hash.new
CSV.open(options[:umbel_to_cyc]) do |file|
  file.each do |umbel, cycid, cyc|
    umbel_to_cyc[umbel] = cycid
  end
end

dbpedia_to_cyc = Hash.new
CSV.open(options[:manual_dbpedia_to_cyc]) do |file|
  file.each do |dbpedia, name|
    dbpedia_to_cyc[dbpedia] = name_service.find_by_term_name(name)
  end
end

CSV.open(options[:output], 'w') do |result|
  CSV.open(options[:dbpedia_to_umbel]) do |file|
    file.shift
    file.each do |id, changed, dbpedia, umbel|
      #p id, dbpedia
      umbel.strip!

      cycid = umbel_to_cyc[umbel]
      if dbpedia_to_cyc.include? dbpedia
        cycid= dbpedia_to_cyc[dbpedia].nil??nil:dbpedia_to_cyc[dbpedia].id
      elsif nil==cycid
        umbel.gsub!('_', '-')

        cycterm = name_service.find_by_term_name(umbel)
        if nil==cycterm
          puts '| '+dbpedia+' | '+umbel+' |  |'
          result << [dbpedia, nil]
          next
        end
        cycid = cycterm.id
      end

      result << [dbpedia, cycid]
    end
  end
end
