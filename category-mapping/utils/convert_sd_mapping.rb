#!/usr/bin/env ruby

require 'bundler/setup'
require 'slop'
require 'csv'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f input.csv -o output.csv\n" +
    "Convert SD mapping to common format"

  on :f=, :input, "Input file with the mapping", required: true
  on :o=, :output, "Output file with converted mapping", required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

CSV.open(options[:input],"r:utf-8") do |input|
  CSV.open(options[:output],"w:utf-8") do |output|
    input.each do |category_name,umbel_name,cyc_id,cyc_name|
      output << [cyc_id,category_name,cyc_name]
    end
  end
end
