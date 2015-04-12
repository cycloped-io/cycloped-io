#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'slop'
require 'csv'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -m mapping.csv -i classification.csv -o converted.csv\n" +
    'Convert external reference classification to Cyc terms.'

  on :m=, :mapping, 'Mapping between external ontology and Cyc', required: true
  on :i=, :instances, 'Classification using the external ontology', required: true
  on :o=, :output, 'Output classification using Cyc terms', required: true
  on :t, :'all-true', 'Flag indicating that all examples are positive'
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

map = {}
CSV.open(options[:mapping]) do |input|
  input.each do |external,cyc_id,cyc_name|
    map[external] = [cyc_id,cyc_name]
  end
end

CSV.open(options[:instances]) do |input|
  CSV.open(options[:output],"w") do |output|
    input.each do |article,type,*rest|
      cyc_type = map[type]
      if cyc_type.nil?
        puts "Missing type for #{article}!"
        next
      end
      row = [article,*cyc_type]
      if options[:'all-true']
        row.push("true")
      end
      output << row
    end
  end
end
