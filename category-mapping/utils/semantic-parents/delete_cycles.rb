#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
require 'csv'
require 'progress'
require 'slop'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -c semantic_parents.csv -o semantic_parents_without_cycles.csv -r resolve_cycles.csv -d database\n"+
             'Creates acyclic graph from Wikipedia categories.'

  on :c=, :parents, 'File with semantic parents', required: true
  on :o=, :output, 'File with semantic parents without cycles', required: true
  on :r=, :relations, 'Relation to delete or add', required: true
  on :d=, :database, 'ROD database with Wikipedia data', required: true
end
begin
  options.parse
rescue Slop::MissingOptionError
  puts options
  exit
end

include Rlp::Wiki
Database.instance.open_database(options[:database] || '../rlp/data/en-2013')

categories = Hash.new

CSV.open(options[:parents]) do |file_parents|
  file_parents.each do |row|
    row.map! { |id| id.to_i }
    category, *parents = row
    parents.delete category
    if not parents.empty?
      categories[category] = parents
    end
  end
end

CSV.open(options[:relations], 'r:UTF-8') do |file_relations|
  file_relations.each do |action, category, parent|
    category_id = Category.find_by_name(category).wiki_id
    parent_id = Category.find_by_name(parent).wiki_id
    p action, category, parent
    if action == 'DEL'
      categories[category_id].delete parent_id
    else #ADD
      categories[category_id].push parent_id
    end
  end
end

CSV.open(options[:output], 'w') do |output|
  categories.each do |category, parents|
    output << [category].concat(parents.map { |c| c }.sort)
  end
end