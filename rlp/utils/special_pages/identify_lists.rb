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
             'Identify list articles.'

  on :o=, :output, 'Output file', required: true
  on :d=, :database, 'ROD database', required: true
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

list_articles = Set.new

Concept.with_progress do |concept|
  if concept.name =~ /(^L|\bl)ist of\b/
    list_articles.add concept
    stats['articles with "list of" in name']+=1
  elsif concept.name =~ /\b(^L|\bl)ist\b/
    stats['other articles with "list" in name']+=1
  end
end

CSV.open(options[:output], 'w') do |csv_lists|
  list_articles.sort_by{|list| list.wiki_id}.each do |list|
    csv_lists << [list.wiki_id, list.name]
  end
end

stats.sort_by{|k,v| v}.reverse.each do |what, count|
  puts what+' - '+count.to_s
end


# LAST RUN
# 100.0% (elapsed: 4.5m)
# other articles with "list of" in name - 82681
# other articles with "list" in name - 202