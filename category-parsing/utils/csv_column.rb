#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'progress'
require 'csv'
require 'slop'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -i input.csv -c number -o filtered.csv\n" +
             'Get n-th column of CSV file.'

  on :i=, :input, 'Input CSV file', required: true
  on :c=, :column, 'Number of CSV column to get', as: Integer, required: true
  on :o=, :output, 'Filtered CSV file', required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

CSV.open(options[:output], "w:utf-8") do |output|
  CSV.open(options[:input], 'r:utf-8').with_progress do |row|
    val = row[options[:column]]
    output << [val]
  end
end