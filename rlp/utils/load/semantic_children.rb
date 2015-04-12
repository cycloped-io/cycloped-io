#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'slop'
require 'rlp/wiki'
require 'progress'
require 'csv'

options = Slop.new do
  banner "Usage: #{$PROGRAM_NAME} -d db_path\n" +
             'Load semantic children using semantic parents.'

  on :d=, 'database', 'Database path', required: true
end
begin
  options.parse
rescue Slop::MissingOptionError
  puts options
  exit
end

include Rlp::Wiki
Database.instance.open_database(options[:database], :readonly => false)


semantic_children = Hash.new

Category.with_progress do |category|
  category.semantic_parents.each do |parent|
    (semantic_children[parent] ||=[]) << category
  end
end

Category.with_progress do |category|
  if semantic_children.include? category
    category.semantic_children = semantic_children[category].sort_by { |child| child.wiki_id }
  else
    category.semantic_children = []
  end
  category.store
end

Database.instance.close_database

