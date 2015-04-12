#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'progress'
require 'csv'
require 'slop'
require 'cycr'
require 'set'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -c classification1.csv -c classification2.csv ... -o merged_classification.csv\n" +
    'Merges any number of classifications.'

  on :c=, :classification, 'Classification to merge', as: Array, required: true
  on :o=, :output, 'Merged classification', required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

positions = Array.new(options[:classification].size){ {} }
files = []
names = Set.new

options[:classification].each.with_index do |classification_file,index|
  puts "Processing #{index+1}/#{options[:classification].size}: #{classification_file}"
  begin
    files << CSV.open(classification_file,'r:utf-8')
    last_position = 0
    files.last.with_progress do |name, *types|
      positions[index][name] = last_position
      names << name
      last_position = files.last.pos
    end
  rescue Interrupt
    next
  end
end

puts "Writing #{names.size} to #{options[:output]}"
CSV.open(options[:output],'w') do |output|
  output_tuple = []
  Progress.start(names.size)
  names.each do |name|
    begin
      Progress.step(1)
      output_tuple << name
      files.each.with_index do |file,index|
        position = positions[index][name]
        next if position.nil?
        file.pos = position
        row = file.shift
        row.shift
        output_tuple.concat(row)
      end
      output << output_tuple
      output_tuple.clear
    rescue Interrupt
      break
    end
  end
  Progress.stop
end
files.each(&:close)
