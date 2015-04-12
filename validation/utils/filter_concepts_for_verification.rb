#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'progress'
require 'csv'
require 'slop'
require 'cycr'
require 'set'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -m reference.csv -i classification.csv -o filtered.csv\n" +
    'Filter classification to only include articles that are present in the reference classification.'

  on :i=, :input, 'Classification with first column as article name', required: true
  on :m=, :classification, 'Reference classification of articles', required: true
  on :o=, :output, 'Filtered classification', required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end


verification = Set.new

CSV.open(options[:classification], "r:utf-8") do |verification_csv|
  verification_csv.with_progress do |row|
    verification.add row.shift
  end
end


CSV.open(options[:output], "w") do |output|
  CSV.open(options[:input], "r:utf-8") do |input|
    input.with_progress do |row|
      article_name = row[0]
      next if !verification.include? article_name
      next if row.empty?
      output << row
    end
  end
end
