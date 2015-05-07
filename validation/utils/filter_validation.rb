#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
$:.unshift "lib"
require 'slop'
require 'csv'
require 'cycr'
require 'progress'

require 'rlp/wiki'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -i validated.csv -f regular_test_set.csv -o filtered_validated.csv\n" +
             "Filter validation file with articles."

  on :i=, :input, "File with validation", required: true
  on :f=, :regular, "File with regular articles", required: true
  on :o=, :output, "Output file", required: true
end

begin
  options.parse
rescue Exception
  puts options
  exit
end

validation = {}

CSV.open(options[:input],'r:utf-8') do |input|
  input.each do |row|
    wiki_name = row[0]
    validation[wiki_name] = row
  end
end


CSV.open(options[:output], "w:utf-8") do |output|
  CSV.open(options[:regular], "r:utf-8") do |regular|
    regular.each do |wiki_name, cyc_id, cyc_name|
      row = validation[wiki_name]
      next if row.nil?
      validation.delete(wiki_name)
      output << row
    end
  end

  validation.each do |k,v|
    output << v
  end
end
