#!/usr/bin/env ruby

require 'bundler/setup'
$:.unshift "lib"
require 'slop'
require 'progress'
require 'csv'
require 'compound/pattern_builder'
require 'rlp/wiki'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f patterns.csv -o filtered.csv \n"+
    "Filter out patterns based on administrative categories.\n"+
    "This works only for simple patterns (without semantic categories)"

  on :f=, :input, "Input file with pattern matches", required: true
  on :o=, :output, "Output file with pattern matches without administrative categories", required: true
  on :d=, :database, "ROD Wikipedia database", required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

Progress.start(`wc -l #{options[:input]}`.to_i)
patterns = {}


include Rlp::Wiki
Database.instance.open_database(options[:database])

CSV.open(options[:input],"r:utf-8") do |input|
  input.each do |row|
    begin
      Progress.step(1)
      pattern,count,*ids = row
      ids.reject!{|id| Category.find_by_wiki_id(id.to_i).administrative? }
      patterns[pattern] = ids
    rescue Interrupt
      puts
      break
    end
  end
end
Progress.stop

CSV.open(options[:output],"w:utf-8") do |output|
  patterns.sort_by{|k,v| -v.size }.each do |pattern,ids|
    output << ids.unshift(ids.size).unshift(pattern)
  end
end

Database.instance.close_database
