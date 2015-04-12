#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'slop'
require 'rlp/wiki'
require 'progress'
require 'csv'
include Rlp::Wiki

# Script for loading redirects.

options = Slop.new do
  banner "Usage: #{$PROGRAM_NAME} -d db_path -l list_pages.csv -i disambiguation_pages.csv -o other_pages.csv\n" +
             'Mark list, disambiguation, index, outline, glossary, data pages.'

  on :d=, 'database', 'Database path', required: true
  on :l=, 'list', 'Input file with list pages', required: true
  on :i=, 'disambiguation', 'Input file with disambiguation pages', required: true
  on :o=, 'other', 'Input file with other special pages (index, outline, glossary, data)', required: true
end
begin
  options.parse
rescue Slop::MissingOptionError
  puts options
  exit
end


Database.instance.open_database(options[:database], :readonly => false)

# Ordered by priority

CSV.open(options[:other], 'r:utf-8') do |input|
  input.each do |concept_id, name|
    concept = Concept.find_by_wiki_id(concept_id.to_i)
    concept.status = :other
    concept.store
  end
end

CSV.open(options[:list], 'r:utf-8') do |input|
  input.each do |concept_id, name|
    concept = Concept.find_by_wiki_id(concept_id.to_i)
    concept.status = :list
    concept.store
  end
end

CSV.open(options[:disambiguation], 'r:utf-8') do |input|
  input.each do |concept_id, name|
    concept = Concept.find_by_wiki_id(concept_id.to_i)
    concept.status = :disambiguation
    concept.store
  end
end

Database.instance.close_database

