#!/usr/bin/env ruby
# encding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
require 'progress'
require 'csv'
require 'slop'
require 'colors'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -d db \n" +
    "Show and export stats of suffixes of Cyc term names"

  on :f=, :input, "File with Cyc terms", required: true
  on :o=, :output, "Output file with full stats", required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

histogram = Hash.new(0)
CSV.open(options[:input]) do |input|
  input.with_progress do |row|
    next unless row.first =~ /-(.*)/
    name = $1
    name = name.gsub(/(?<=[a-z])([A-Z])(?=[a-z])/){|m| " " + m[0].downcase }
    histogram[name] += 1
  end
end

puts "| word(s) | count |"
puts "|---------|------:|"
CSV.open(options[:output],"w") do |output|
  histogram.sort_by{|k,v| -v }.each do |word,count|
    output << [word,count]
    next if count < 30
    puts "| #{word} | #{count} |"
  end
end
