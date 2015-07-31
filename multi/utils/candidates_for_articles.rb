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
require 'yajl'
require 'auto_serializer'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -i phrase_candidates.csv -o article_candidates.csv \n" +
             'Assign candidates to articles.'

  on :i=, :input, 'CSV list of phrases with Cyc candidates', required: true
  on :o=, :output, 'Articles with assigned candidates', required: true
  on :d=, :database, 'ROD database path'
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end


@nouns = Nouns.new

def singularize_name_nouns(name, head)
  names = [name]
  singularized_heads = @nouns.singularize(head)
  if not singularized_heads.nil?
    singularized_heads.each do |singularized_head|
      names << name.sub(/\b#{Regexp.quote(head)}\b/, singularized_head)
    end
  end
  names
end

include Rlp::Wiki
Database.instance.open_database(options[:database] || '../../en-2013/')


def read_phrase_candidates
  phrase_candidates = {}
  CSV.open(options[:input]) do |input|
    input.with_progress do |phrase, *candidates|
      phrase_candidates[phrase] = candidates.each_slice(2).to_a
    end
  end
  return phrase_candidates
end

phrase_candidates = AutoSerializer.auto(:read_phrase_candidates)


simplifier = Syntax::Stanford::Simplifier



CSV.open(options[:output], 'w') do |output|
  Concept.with_progress do |concept|
    tuple = {}
    concept.types_trees.each_with_index do |tree, tree_index|
      names = simplifier.new(tree).simplify.to_a

      names_candidates = {}

      head_node = tree.find_head_noun
      if head_node
        head = head_node.content
        names.each do |name|
          simplified_names = singularize_name_nouns(name, head)
          simplified_names.each do |simplified_name|
            candidates = phrase_candidates[simplified_name]
            if candidates.nil?
              p simplified_name
              next
            end
            if !candidates.empty?
              names_candidates[simplified_name]= candidates
            end
          end
        end
        tuple['fs'+tree_index.to_s]=names_candidates if !names_candidates.empty?
      else
        p concept.name, tree.to_s
      end


    end
    output << [concept.name, Yajl::Encoder.encode(tuple)]
  end
end

