#!/usr/bin/env ruby

require 'bundler/setup'
$:.unshift "lib"
require 'slop'
require 'progress'
require 'csv'
require 'compound/pattern_builder'
require 'rlp/wiki'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f patterns.csv -o filtered.csv -P administrative?\n"+
    "Filter out patterns based on category predicate.\n"+
    "This works only for simple patterns (without semantic categories)"

  on :f=, :input, "Input file with pattern matches", required: true
  on :o=, :output, "Output file with pattern matches without administrative categories", required: true
  on :d=, :database, "ROD Wikipedia database", required: true
  on :p=, :select, "Predicate used to select categories"
  on :P=, :reject, "Predicate used to reject categories"
  on :s=, :support, "Minimum support to print pattern", as: Integer, default: 20
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

if options[:reject].nil? && options[:select].nil?
  puts "Either reject or select has to be specified"
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
      ids.map!{|id| Category.find_by_wiki_id(id.to_i) }
      if options[:select]
        ids.select!{|c| c.send(options[:select]) }
      end
      if options[:reject]
        ids.reject!{|c| c.send(options[:reject]) }
      end
      next if ids.size < options[:support]
      patterns[pattern] = ids.map(&:wiki_id)
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
