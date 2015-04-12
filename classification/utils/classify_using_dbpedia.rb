#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'progress'
require 'csv'
require 'slop'
require 'cycr'
require 'yaml'
require 'set'

$:.unshift '../category-mapping/lib'
require 'mapping/cyc_term'
require 'mapping/service/cyc_name_service'
require 'mapping/bidirectional_map'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -b dbpedia_cyc_mapping.csv -i dbpedia_instances.csv -y dbpedia_hierarchy.yml -o output.csv \n" +
             'Converts DBpedia classification to Cyc classification.'

  on :m=, :mapping, 'File with DBpedia to Cyc mapping', required: true
  on :i=, :input, 'File with DBpedia instances in CSV', required: true
  on :o=, :output, 'File with DBpedia instances to Cyc mapping', required: true
  on :h=, :host, 'Cyc host (localhost)', default: 'localhost'
  on :p=, :port, 'Cyc port (3601)', as: Integer, default: 3601
  on :r=, :probability, 'Probability assigned to the classification', as: Float, default: 0.95
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


dbpedia_to_cyc = Hash.new
CSV.open(options[:mapping]) do |file|
  file.each do |dbpepdia, cyc_id|
    next if cyc_id.nil?
    term = name_service.find_by_id(cyc_id)
    dbpedia_to_cyc[dbpepdia] = term
  end
end

CSV.open(options[:output],'w') do |result|
  CSV.open(options[:input],'r:utf-8') do |reader|
    reader.with_progress do |article, *dbpedia_types|
      # skip career stations, etc.
      next if article =~ /  \d+$/
      types = dbpedia_types.map{|cl| dbpedia_to_cyc[cl] }.compact.map{|t| [t.id,t.to_ruby.to_s,options[:probability]] }.flatten(1)
      next if types.empty?
      result << [article, *types]
    end
  end
end
