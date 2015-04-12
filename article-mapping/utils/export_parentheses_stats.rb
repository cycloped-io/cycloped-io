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
    "Show and export stats for words in parentheses in article names"

  on :d=, :database, "Rod database", required: true
  on :o=, :output, "Output file with full stats", required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

include Rlp::Wiki

Database.instance.open_database(options[:database])
histogram = Hash.new(0)
Concept.each.with_index.with_progress do |concept,index|
  next unless concept.name =~ /\((.*)\)/
  histogram[$1] += 1
end
Database.instance.close_database

puts "| word(s) | count |"
puts "|---------|------:|"
CSV.open(options[:output],"w") do |output|
  histogram.sort_by{|k,v| -v }.each do |word,count|
    output << [word,count]
    next if count < 30
    puts "| #{word} | #{count} |"
  end
end
