#!/usr/bin/env ruby

require 'bundler/setup'
$:.unshift "lib"
require 'slop'
require 'progress'
require 'csv'
require 'compound/pattern_builder'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f entity_matches.csv -o patterns [-n] [-l order]\n"+
    "Discover patterns in category names."

  on :f=, :input, "Input file with article name matches", required: true
  on :o=, :output, "Prefix of output files with pattern match results", required: true
  on :m=, :mode, "Discovery mode: s - simple (default), c - concepts"
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

builder = Compound::PatternBuilder.new
max_order = 4
Progress.start(`wc -l #{options[:input]}`.to_i)
patterns = {}
(1..max_order).each{|i| patterns[i] = Hash.new{|h,e| h[e] = [] } }

CSV.open(options[:input],"r:utf-8") do |input|
  input.each do |row|
    begin
      Progress.step(1)
      category_id,category_name,*tuples = row
      builder.build(category_name,tuples.each_slice(3).to_a,max_order) do |pattern,order,concepts|
        patterns[order][pattern] << category_id
        if options[:mode] == "c"
          concepts.each do |concept|
            patterns[order][pattern] << concept
          end
        end
      end
    rescue Interrupt
      puts
      break
    end
  end
end
Progress.stop

(1..max_order).each do |order|
  CSV.open(options[:output] + "_#{order}.csv","w:utf-8") do |output|
    patterns[order].sort_by{|k,v| -v.size }.each do |pattern,ids_with_concepts|
      if options[:mode] == "c"
        output << ids_with_concepts.unshift(ids_with_concepts.size/(order+1)).unshift(pattern)
      else
        output << ids_with_concepts.unshift(ids_with_concepts.size).unshift(pattern)
      end
    end
  end
end
