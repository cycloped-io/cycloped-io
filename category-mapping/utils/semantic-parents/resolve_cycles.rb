#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
require 'cycr'
require 'csv'
require 'progress'
require 'slop'

include Rlp::Wiki


options = Slop.new do
  banner "#{$PROGRAM_NAME} -p semantic_parents.csv -c semantic_cycles.csv -o sample_resolve_cycles.csv -d database\n"+
             'Prints categories with parents.'

  on :p=, :parents, 'File with semantic parents', required: true
  on :c=, :cycles, 'Semantic cycles', required: true
  on :o=, :output, 'Sample file with cycles resolution (delete all relations)', required: true
  on :d=, :database, 'ROD database with Wikipedia data', required: true
end
begin
  options.parse
rescue Slop::MissingOptionError
  puts options
  exit
end

Database.instance.open_database(options[:database])

categories=Hash.new
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

CSV.open(options[:output],'w') do |file_resolve|
CSV.open(options[:cycles]) do |file_cycles|
  file_cycles.each do |row|
    cycle = row.map { |name| Category.find_by_name(name) }

    cycle.each do |category|
      puts '**'+category.name+'**'
      categories[category.wiki_id].map { |wiki_id| Category.find_by_wiki_id(wiki_id) }.each do |parent|
        puts '- '+parent.name
      end
      puts
    end

    decision=''
    category1=cycle[0]
    category2=cycle[1]
    if cycle.size==2
      if (categories[category1.wiki_id]&categories[category2.wiki_id]).size>0
        decision = 'The same parent - delete relation in both directions'
      elsif not categories.include?(category1.wiki_id) || categories[category1.wiki_id].empty?
        decision = category1.name+' would be orphaned'
      elsif not categories.include?(category2.wiki_id) || categories[category2.wiki_id].empty?
        decision = category2.name+' would be orphaned'
      end
    end

    file_resolve << ['DEL',category1.name, category2.name]
    file_resolve << ['DEL',category2.name, category1.name]

    puts
    puts '**Decision:** '+decision
    puts
    puts '---'
    puts
  end
end end