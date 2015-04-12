#!/usr/bin/env ruby

require 'bundler/setup'
$:.unshift "lib"
require 'csv'
require 'slop'
require 'progress'
require 'resolver/reader'

options = Slop.new do
  banner "#{$PRGORAM_NAME} -f partitions.csv -o classification.csv\n" +
    "Export classification from partitions file"

  on :f=, :input, "Input file with partitions", required: true
  on :o=, :output, "Output file with classification", required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

reader = Resolver::Reader.new

CSV.open(options[:input],"r:utf-8") do |input|
  CSV.open(options[:output],"w") do |output|
    input.with_progress do |row|
      article_name, partitions = reader.extract_partitions(row)
      next if partitions.empty?
      output_row = [article_name]
      best_partition = partitions.sort_by{|p| - p.support }.first
      best_partition.each do |(id,name),_|
        output_row << id << name
      end
      output << output_row
    end
  end
end
