#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'csv'
require 'slop'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -i eponymous_unsorted.csv -o eponymous_sorted.csv\n" +
    "Sort and merge eponymous links."

  on :i=, :input, "Input file (CSV)", required: true
  on :o=, :output, "Output file with sorted eponymous categories (CSV)", required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

categories = Hash.new{|h,e| h[e] = [] }

CSV.open(options[:input],"r:utf-8") do |input|
  input.each do |row|
    category_id,category_name,concept_id,concept_name = row
    categories[category_id] << concept_name
  end
end

CSV.open(options[:output],"w:utf-8") do |output|
  categories.each do |category_id,concept_ids|
    output << [category_id,concept_ids.join("|")]
  end
end
