#!/usr/bin/env ruby

require 'bundler/setup'

require 'slop'
require 'csv'
require 'progress'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f matches.csv -c constraints.csv -o filtered_matches.csv [-p port] [-h host] [-v]\n" +
    "Divide constraints of patterns for each relation argument"

  on :f=, :input, "Constraints of predicates (CSV)", required: true
  on :o=, :output, "Prefix of output file with divided constraints (CSV)", required: true
end


begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

histogram1 = Hash.new{|h,e| h[e] = Hash.new(0) }
histogram2 = Hash.new{|h,e| h[e] = Hash.new(0) }
CSV.open(options[:input],"r:utf-8") do |input|
  input.with_progress do |entity,cyc_id1,cyc_name1,cyc_id2,cyc_name2,count|
    histogram1[entity][[cyc_id1,cyc_name1]] += count.to_i
    histogram2[entity][[cyc_id2,cyc_name2]] += count.to_i
  end
end

[histogram1,histogram2].each.with_index do |histogram,index|
  name = index == 0 ? "first" : "second"
  CSV.open("#{options[:output]}_#{name}.csv","w") do |output|
    histogram.each do |entity,terms|
      output << terms.to_a.flatten.unshift(entity)
    end
  end
end
