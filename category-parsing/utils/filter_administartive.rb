#!/usr/bin/env ruby



$:.unshift "lib"

require 'bundler/setup'
require 'set'
require 'csv'
require 'slop'
require 'progress'
require 'syntax/penn_tree'
require 'syntax/parsed_sentence'
require 'syntax/dependencies'
require 'syntax/stanford/converter'

opts = Slop.new do
  banner 'Usage: filter_administrative.rb -p parsed_path -o output_path -a administrative_path'

  on 'p', 'sentences_path', 'Parsed categories in CSV', argument: :mandatory, required: true
  on 'o', 'output_path', 'Output CSV file with heads', argument: :mandatory, required: true
  on 'a', 'administrative_path', 'Administrative categories', argument: :mandatory, required: true
end
begin
  opts.parse
rescue Slop::MissingOptionError
  puts opts
  exit
end

sentences_path = opts[:sentences_path]
output_path = opts[:output_path]
administrative_path = opts[:administrative_path]



file_parsed = CSV.open(sentences_path, "r")
file_output = CSV.open(output_path, "w")
file_administrative = CSV.open(administrative_path, "r")

administrative = Set.new
file_administrative.each do |cat|
  administrative.add(cat[0].strip)
end
file_administrative.close

b = Set.new
counter = 0
file_parsed.each do |row|
  #p row[0][0..-11]
  #p row[0]
  if administrative.include?(row[0])
    counter += 1
    b.add(row[0])
    next
  end
  file_output << row

end

file_parsed.close
file_output.close

puts counter
puts administrative.size
puts b.size
#p administrative-b



# 138377
# 138391
# 138377
#<Set: {"Wikipedia files with unknown source as of 4 October 2013", "Wikipedia files needing editor assistance at upload as of 4 October 2013", "Wikipedia files with no non-free use rationale as of 4 October 2013", "Orphaned non-free use Wikipedia files as of 4 October 2013", "Disputed non-free Wikipedia files as of 4 October 2013", "Wikipedia files with the same name on Wikimedia Commons as of 4 October 2013", "Wikipedia files with a different name on Wikimedia Commons as of 4 October 2013", "Frasier episode redirects to lists", "October 2013 peer reviews", "Infobox holiday with missing field", "Convert invalid units", "Convert invalid options", "Wikipedia files missing permission as of 2 October 2013", "Osku County geography stubs"}>
