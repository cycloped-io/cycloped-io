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
  banner "#{$PROGRAM_NAME} -o lists.csv\n" +
             'Identify disambiguation pages.'

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

disambiguation_pages = Set.new
disambiguation_pages_names = Set.new

disambiguation = Category.find_by_name('All disambiguation pages')
disambiguation_pages.merge disambiguation.concepts

Category.with_progress do |category|
  if category.name =~ /\b[Dd]isambiguation pages\b/
    disambiguation_pages_names.merge category.concepts
  elsif category.name =~ /\b[Dd]isambiguation\b/
    p category.name
  end
end

puts 'Disambiguation pages from category "All disambiguation pages": '+disambiguation_pages.size.to_s
puts 'Disambiguation pages from other categories with "disambiguation pages" in name: '+(disambiguation_pages_names-disambiguation_pages).size.to_s

CSV.open(options[:output], 'w') do |csv_disambiguation|
  disambiguation_pages.sort_by{|page| page.wiki_id}.each do |page|
    csv_disambiguation << [page.wiki_id, page.name]
  end
end
