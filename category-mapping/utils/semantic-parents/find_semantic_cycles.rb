#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
require 'csv'
require 'progress'
require 'slop'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -c semantic_parents.csv -o semantic_cycles.csv -d database\n"+
             'Finds semantic cycles.'

  on :c=, :parents, 'File with semantic parents', required: true
  on :o=, :output, 'Semantic cycles', required: true
  on :d=, :database, 'ROD database with Wikipedia data', required: true
end
begin
  options.parse
rescue Slop::MissingOptionError
  puts options
  exit
end

include Rlp::Wiki
Database.instance.open_database(options[:database])

$categories = Hash.new

CSV.open(options[:parents]) do |f|
  f.each do |row|
    row.map! { |id| id.to_i }
    category, *parents = row
    parents.delete category
    if not parents.empty?
      $categories[category] = parents
    end
  end
end

puts $categories.size

$checked = Set.new
$output = CSV.open(options[:output], 'w')

def dfs_up(start, level, parents)
  if $checked.include? start
    return
  end
  $checked.add start

  if not $categories.has_key? start
    return false
  end

  parents = parents.dup
  parents.push(start)

  $categories[start].each do |parent|

    if parents.include?(parent)

      index = parents.index parent
      cycle_ids = parents[index..-1]
      cycle=cycle_ids.map! { |category_id| Category.find_by_wiki_id(category_id) }
      cycle_names = cycle.map { |c| c.name }
      $output << cycle_names
      p cycle_names
    else
      dfs_up(parent, level+1, parents)
    end
  end
end


$categories.with_progress do |category, parents|
  dfs_up(category, 0, [])
end

$output.close