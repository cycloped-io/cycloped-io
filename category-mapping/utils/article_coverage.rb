#!/usr/bin/env ruby
# encding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
require 'irb'
require 'set'
require 'progress'
require 'csv'
require 'slop'
require 'colors'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -d db -f mapping.csv [-F 1] [-i n|i]\n" +
    "Compute article coverage based on category mapping and semantic parent/child relations"

  on :d=, :database, "Rod database", required: true
  on :f=, :input, "Input file with category mapping (CSV)", required: true
  on :F=, :"field-number", "Field containing the identifier of category (from 0, default: 0)", default: 0, as: Integer
  on :i=, :identifier, "Category identifier: n - name (default), i - wikipedia id", default: "n"
  on :c=, :categories, "Dump of covered category ids"
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

include Rlp::Wiki

mapped_categories = []
CSV.open(options[:input],"r:utf-8") do |input|
  input.with_progress do |row|
    mapped_categories.push row[options[:"field-number"]]
  end
end

Database.instance.open_database(options[:database])

def get_all_subcategory_concepts(category,visited)
  concepts = Set.new
  stack = [category]
  while not stack.empty?
    category = stack.pop
    next if visited.include?(category)
    visited.add(category)
    concepts.merge(category.concepts)
    category.semantic_children.each do |child|
      stack.push(child) unless visited.include?(child)
    end
  end
  return concepts
end

concepts = Set.new
visited = Set.new

mapped_categories.with_progress do |category_identifier|
  begin
    if options[:identifier] == "i"
      category = Category.find_by_wiki_id(category_identifier.to_i)
    else
      category = Category.find_by_name(category_identifier)
    end
    covered_concepts = get_all_subcategory_concepts(category,visited)
    concepts.merge covered_concepts
  rescue Interrupt
    puts
    break
  rescue Exception => ex
    puts category_identifier.to_s.hl(:red)
    STDERR.puts ex
  end
end

puts "Articles coverage: #{concepts.size}/#{Concept.count}"
puts "Category coverage: #{visited.size}/#{Category.count}"
if options[:categories]
  CSV.open(options[:categories],"w") do |output|
    visited.each do |category|
      output << [category.wiki_id]
    end
  end
end

Database.instance.close_database
