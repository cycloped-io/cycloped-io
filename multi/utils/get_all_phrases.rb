#!/usr/bin/env ruby
# encoding: utf-8


require 'bundler/setup'
$:.unshift '../category-mapping/lib'
require 'rlp/wiki'
require 'progress'
require 'csv'
require 'slop'
require 'set'
require 'colors'
require 'cycr'
require 'mapping'
require 'experiment_arguments_log/auto'
require 'syntax'
require 'nouns/nouns'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -o phrases.csv \n" +
             'Generates all phrases for denotation mapping.'

  on :o=, :output, 'CSV list of phrases', required: true

  on :h=, :host, 'Cyc host', default: 'localhost'
  on :p=, :port, 'Cyc port', as: Integer, default: 3601
  on :c=, :'category-filters', "Filters for categories: c - collection, s - most specific,\n" +
            'n - noun, r - rewrite of, l - lower case, f - function, c|i - collection or individual, b - black list', default: 'c:r:f:l:d'
  on :g=, :'genus-filters', 'Filters for genus proximum types: (as above)', default: 'c:r:f:l:d'
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

cyc = Cyc::Client.new(cache: true, host: options[:host], port: options[:port])
name_service = Mapping::Service::CycNameService.new(cyc)

Thing = name_service.find_by_term_name('Thing')

black_list_reader = Mapping::BlackListReader.new(options[:'black-list'])
name_service = Mapping::Service::CycNameService.new(cyc)
filter_factory = Mapping::Filter::Factory.new(cyc: cyc, black_list: black_list_reader.read)
term_provider = Mapping::TermProvider.
    new(cyc: cyc, name_service: name_service,
        category_filters: filter_factory.filters(options[:'category-filters']),
        genus_filters: filter_factory.filters(options[:'genus-filters']))


include Rlp::Wiki
Database.instance.open_database(options[:database] || '../../en-2013/')

used_names = Set.new

CSV.open('phrases.csv') do |input|
  input.each do |row|
    used_names << row.first
  end
end



simplifier = Syntax::Stanford::Simplifier

def generate_phrases(tree, simplifier, used_names, term_provider, output)
  names = simplifier.new(tree).simplify.to_a

  head_node = tree.find_head_noun
  if head_node
    head = head_node.content
    names.each do |name|
      next if used_names.include?(name)
      used_names << name
      simplified_names = (term_provider.singularize_name_nouns(name, head) + term_provider.singularize_name_nouns(uncapitalize(name), uncapitalize(head))).uniq
      simplified_names.each do |simplified_name|
        output << [simplified_name]
      end
    end
  end
end

CSV.open('phrases.csv', 'a') do |output|
  Concept.with_progress do |concept|
    concept.types_trees.each do |tree|
      generate_phrases(tree, simplifier, used_names, term_provider, output)
    end
  end
end


CSV.open('phrases.csv', 'a') do |output|
  Category.with_progress do |category|
    category.head_trees.each do |tree|
      generate_phrases(tree, simplifier, used_names, term_provider, output)
    end
  end
end