#!/usr/bin/env ruby

require 'bundler/setup'
$:.unshift 'lib'

require 'csv'
require 'slop'
require 'progress'
require 'syntax/penn_tree'
require 'syntax/parsed_sentence'
require 'syntax/dependencies'
require 'syntax/stanford/converter'
require 'nouns/nouns'

options = Slop.new do
  banner "Usage: #{$PROGRAM_NAME} -c parsed_categories.csv -o parsed_categories_with_heads.csv -e errors.csv\n"+
             'Finds head nouns'

  on :c=, 'parsed_categories', 'Parsed categories', required: true
  on :o=, 'output', 'Parsed categories with heads', required: true
  on :e=, 'errors', 'Heads not found correctly', required: true
end
begin
  options.parse
rescue Slop::MissingOptionError
  puts options
  exit
end

nouns = Nouns.new('data/nouns')

parsed_categories = options[:parsed_categories]
output = options[:output]
errors = options[:errors]

file_parsed_categories = CSV.open(parsed_categories, 'r')
file_output = CSV.open(output, 'w')
file_errors = CSV.open(errors, 'w')
file_stats = CSV.open(output+'.stats', 'w')
file_stats_err = CSV.open(output+'.stats.err', 'w')

counter = 0

Progress.start(file_parsed_categories.stat.size)

file_parsed_categories.with_progress do |row|
  Progress.set(file_parsed_categories.pos)
  category_name, preprocessed_category_name, full_parse, dependency=row

  tree = Syntax::PennTree.new(full_parse)
  nouns.fix_penn_tree(tree.tree)
  row[2] = tree.to_s
  dependencies = Syntax::Dependencies.new(dependency.split("\n"))
  ps = Syntax::ParsedSentence.new(tree, dependencies)

  heads = [ps.dep_head] # removing from tree can cause errors in methods based on dependencies
  tree.remove_parenthetical!
  heads.concat ps.heads

  stats = [tree.tree.to_s, tree.tree.tree_without_content.to_s, tree.tree.tree_without_content_and_word_level.to_s]

  tree.remove_prepositional_phrases!

  heads.push tree.find_last_plural_noun
  heads.push tree.find_last_nominal

  heads_stats = heads.map { |h| h.nil? ? nil : h.find_parent_np.to_s }
  heads_without_nils = heads.select { |h| not h.nil? }
  nps = heads_without_nils.map { |h| h.find_parent_np.to_s }

  if nps.uniq.size==1 and heads.size>=2
    counter += 1
    file_output << row + [heads_without_nils[0].find_parent_np.to_s, heads_without_nils[0].content, heads_without_nils[0].parent.plural_noun?]
    file_stats << row + stats + [tree.tree.to_s, tree.tree.tree_without_content, tree.tree.tree_without_content_and_word_level] + heads_stats
  else
    #p category_name
    #p heads
    file_errors << [category_name] + heads
    file_output << row + [nil, nil, nil]
    file_stats_err << row + stats + [tree.tree.to_s, tree.tree.tree_without_content, tree.tree.tree_without_content_and_word_level] + heads_stats
  end


end
Progress.stop

file_parsed_categories.close
file_output.close
file_errors.close
file_stats.close
file_stats_err.close

puts counter # 869601
