#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'slop'
require 'csv'
require 'yaml'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -m mapping.yml -o mapping.csv\n" +
    'Convert mapping from external scheme in YAML to CSV.'

  on :m=, :mapping, 'Mapping between external ontology and Cyc (YAML)', required: true
  on :o=, :output, 'Output mapping from cyc terms to external types in CSV format', required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

mapping = YAML.load_file(options[:mapping])
CSV.open(options[:output],"w") do |output|
  mapping.each do |external_id,mappings|
    mappings.each do |tuple|
      output << [tuple[:cyc_id],tuple[:cyc_name],external_id]
    end
  end
end
