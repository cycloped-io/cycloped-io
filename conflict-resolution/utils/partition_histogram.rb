#!/usr/bin/env ruby

require 'bundler/setup'
require 'csv'
require 'slop'
require 'progress'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f partitions.csv -o histogram.csv"

  on :f=, :input, "Input file with partitions", required: true
  on :o=, :output, "Output file with histogram", required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

histogram = Hash.new{|h,e| h[e] = [0.0,0.0] }

CSV.open(options[:input],"r:utf-8") do |input|
  input.with_progress do |row|
    article = row.shift
    next if row.empty?
    partitions = []
    row.each do |element|
      case element
      when "P"
        partitions << []
      when /^\d+(\.\d+)?$/
        partitions.last << element.to_f
      else
        partitions.last << element
      end
    end
    total_support = 0
    local_histogram = Hash.new(0)
    partitions.each do |partition_support,*tuples|
      total_support += partition_support
      tuples.each_slice(3) do |id,name,support|
        local_histogram[name] += partition_support
      end
    end
    local_histogram.each do |name,support|
      prev_support,prev_total = histogram[name]
      histogram[name] = [prev_support+support,prev_total+total_support]
    end
  end
end
global_histogram = Hash.new(0)
histogram.each do |name,(support,total)|
  global_histogram[support/total] += 1
end

CSV.open(options[:output],"w") do |output|
  global_histogram.sort_by{|reliability,count| reliability }.each do |reliability,count|
    output << [reliability,count]
  end
end
