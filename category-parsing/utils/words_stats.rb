#!/usr/bin/env ruby


require 'bundler/setup'
require 'csv'
require 'set'
require 'slop'
require 'progress'
$:.unshift 'lib'
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


file_categories.with_progress do |row|
  category_name = row[1]
  Set.new(category_name.split(' ')).each do |word|
    (char_stats[word] ||= []) << category_name
  end
  if category_name =~ /[1-9][0-9]{3}/
    (char_stats['YEAR_REGEXP'] ||= []) << category_name
  end
end

file_categories.close

puts '| Word | Category count | Sample |'
puts '| --- | --- | --- |'
char_stats.sort_by{|_,v| v.count}.reverse.each do |word,categories|
  puts '| '+ word + ' | ' + categories.count.to_s + ' | ' + categories.sample + ' |'
end
