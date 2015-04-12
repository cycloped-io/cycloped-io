#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
$:.unshift 'lib'
require 'slop'
require 'csv'
require 'cycr'
require 'progress'
require 'benchmark'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -o indexes_outlines_glossaries_data.csv\n" +
             'Identify indexes, outlines, glossaries and data pages.'

  on :o=, :output, 'Output file', required: true
  on :d=, :database, 'ROD database', default: '../rlp/data/en-2013'
end

begin
  options.parse
rescue Exception => ex
  puts ex
  puts options
  exit
end

include Rlp::Wiki
Database.instance.open_database(options[:database])


stats = Hash.new(0)


indexes_categories = Set.new
indexes_articles = Set.new

Category.with_progress do |category|
  if category.name =~ /^(Indexes|Outlines|Glossaries) of\b/
    stats['categories with "Indexes of" in name'] += 1
    indexes_categories.add category
    indexes_articles.merge category.concepts

  end
end

p indexes_categories.size, indexes_articles.size

Concept.with_progress do |concept|
  if indexes_articles.include? concept
    next
  elsif concept.name =~ /^(Index of .* (articles|games)|Outline of|Glossary of)\b/
    indexes_articles.add concept
  elsif concept.name =~ /\(data page\)/
    indexes_articles.add concept
  end
end

p indexes_categories.size, indexes_articles.size


CSV.open(options[:output], 'w') do |csv_output|
  indexes_articles.sort_by{|page| page.wiki_id}.each do |page|
    csv_output << [page.wiki_id, page.name]
  end
end