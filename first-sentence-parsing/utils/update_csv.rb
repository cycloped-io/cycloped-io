#!/usr/bin/env ruby

require 'bundler/setup'
require 'csv'
require 'slop'
require 'progress'

options = Slop.new do
  banner "Usage: #{$PROGRAM_NAME} -a a.csb -b b.csv -o o.csv\n"+
             'Update CSV A with CSV B using first column as key'

  on :a=, 'a', 'CSV A', required: true
  on :b=, 'b', 'CSV B', required: true
  on :o=, 'output', 'CSV A with updated rows with CSV B', required: true
end
begin
  options.parse
rescue Slop::MissingOptionError
  puts options
  exit
end

data = Hash.new()
CSV.open(options[:b], 'r:utf-8') do |b|
  b.with_progress do |row|
    key=row.first
    data[key]=row
  end
end

CSV.open(options[:a], 'r:utf-8') do |a|
  CSV.open(options[:output], 'w:utf-8') do |output|
    a.with_progress do |row|
      key=row.first
      if data.include? key
        output << data[key]
      else
        output << row
      end
    end
  end
end