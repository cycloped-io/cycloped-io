#!/usr/bin/env ruby

require 'bundler/setup'
$:.unshift "lib"
require 'slop'
require 'progress'
require 'csv'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -i matches.csv -o output.csv -l length\n"+
    "Group pattern matches by patterns"

  on :i=, :input, "File with pattern matches for individual categories", required: true
  on :o=, :output, "Output file", required: true
  on :c=, :count, "Limit input reading to find first n patterns", as: Integer
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

patterns = Hash.new{|h,e| h[e] = [] }
CSV.open(options[:input],"r:utf-8") do |input|
  input.with_progress do |wiki_id,category_name,*matches|
    matches.each_slice(2) do |pattern,matched|
      patterns[pattern] << wiki_id
    end
    break if options[:count] && patterns.size > options[:count]
  end
end
CSV.open(options[:output],"w") do |output|
  patterns.each do |pattern,ids|
    output << ids.unshift(ids.size).unshift(pattern)
  end
end
