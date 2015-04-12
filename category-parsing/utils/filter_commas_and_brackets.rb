#!/usr/bin/env ruby

$:.unshift "lib"

require 'bundler/setup'
require 'csv'
require 'slop'
require 'progress'
require 'syntax/penn_tree'
require 'syntax/parsed_sentence'
require 'syntax/dependencies'
require 'syntax/stanford/converter'

options = Slop.new do
  banner "Usage: #{$PROGRAM_NAME} -c categories.csv -o preprocessed_categories.csv\n"+
  'Filter parentheses and commas from category names.'

  on :c=, 'categories', 'CSV with category names', required: true
  on :o=, 'preprocessed_categories', 'CSV with categories and categories without commas and brackets', required: true

end
begin
  options.parse
rescue Slop::MissingOptionError
  puts options
  exit
end

categories = options[:categories]
preprocessed_categories = options[:preprocessed_categories]

stats = Hash.new(0)

CSV.open(preprocessed_categories, 'w') do |file_preprocessed_categories|
  CSV.open(categories, 'r') do |file_categories|

    file_categories.with_progress do |row|
      category_name=row.first
      preprocessed_category_name = category_name.dup

      brackets = preprocessed_category_name.gsub!(/ \(.*?\)/, '') # brackets
      stats['Removed brackets'] += 1 if brackets

      commas = preprocessed_category_name.gsub!(/, (\p{Lu}[^ ,]* ?){1,2}/u, ' ') # commas specifying locations
      stats['Removed commas specifying locations'] += 1 if commas

      file_preprocessed_categories << [category_name, preprocessed_category_name]
    end
  end
end

stats.each do |name, value|
  puts name+': '+value.to_s
end