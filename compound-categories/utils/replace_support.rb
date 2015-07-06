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
  banner "#{$PROGRAM_NAME} -f mapping.csv -m filtered.csv -o new_mapping.csv\n" +
             "Replace support and filter patterns in patter-to-term mapping"

  on :f=, :input, "File with pattern mapping", required: true
  on :o=, :output, "File with update mapping", required: true
  on :m=, :filter, "File with corrected values for pattern support used to filter the original mapping", required: true
  on :s=, :support, "Minimu support for pattern to be processed", default: 20, as: Integer
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

patterns = {}
CSV.open(options[:filter],"r:utf-8") do |input|
  input.with_progress do |row|
    pattern,support = row.shift(2)
    patterns[pattern] = support.to_i
  end
end

CSV.open(options[:output],"w") do |output|
  CSV.open(options[:input],"r:utf-8") do |input|
    input.with_progress do |row|
      pattern,support = row.shift(2)
      next unless patterns.has_key?(pattern)
      next if patterns[pattern] < options[:support]
      output << row.unshift(patterns[pattern]).unshift(pattern)
    end
  end
end
