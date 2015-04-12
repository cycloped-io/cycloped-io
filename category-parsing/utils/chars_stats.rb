#!/usr/bin/env ruby

$:.unshift 'lib'

require 'bundler/setup'
require 'csv'
require 'set'
require 'slop'
require 'progress'
require 'syntax/penn_tree'
require 'syntax/parsed_sentence'
require 'syntax/dependencies'
require 'syntax/stanford/converter'


#Compute char distribution in category names.

opts = Slop.new do
  banner 'Usage: char_stats.rb -c parsed_with_heads.csv'

  on 'c', 'categories', 'CSV with category names in second column', argument: :mandatory, required: true
end
begin
  opts.parse
rescue Slop::MissingOptionError
  puts opts
  exit
end

categories = opts[:categories]

char_stats = Hash.new

file_categories = CSV.open(categories, 'r')

Progress.start(file_categories.stat.size)
file_categories.each do |row|
  Progress.set(file_categories.pos)
  category_name = row[1]
  Set.new(category_name.split('')).each do |char|
    (char_stats[char] ||= []) << category_name
  end

end
Progress.stop
file_categories.close

puts '| Char | Category count | Sample |'
puts '| --- | --- | --- |'
char_stats.sort_by{|_,v| v.count}.reverse.each do |char,categories|
  next if char =~ /\p{L}/u # omit letters
  puts '| '+ char + ' | ' + categories.count.to_s + ' | ' + categories.sample + ' |'
end
