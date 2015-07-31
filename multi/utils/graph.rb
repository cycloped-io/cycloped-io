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
require 'dbm'
require './utils/graph_libs.rb'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -o \n" +
             'Calculate best candidates.'

  on :o=, :output, 'Informations with best candidates', required: true
  on :m=, :mode, 'Mode: c - categories, a - articles', required: true

  on :h=, :host, 'Cyc host', default: 'localhost'
  on :p=, :port, 'Cyc port', as: Integer, default: 3601
  on :d=, :database, 'ROD database path'
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

include Rlp::Wiki
Database.instance.open_database(options[:database] || '../../en-2013/')

$category_candidates = DBM.open('category_candidate')
$article_candidates = DBM.open('joined')
$assigned = {}


#TODO infer categories, e.g. Boston Bruins players

last = nil
CSV.open(options[:output]) do |input|
  input.with_progress do |row|
    last = row.first
  end
end

if options[:mode]=='c'
  prefix = 'Category:'
  entities = Category
else
  prefix = ''
  entities = Concept
end


omit=true
CSV.open(options[:output], 'a') do |output|
  entities.with_progress do |entity|
    if last.nil?
      omit=false
    end
    if omit && last==prefix+entity.name
      omit=false
      next
    end
    next if omit


    entity_name=entity.name

    if options[:mode]=='c'
      node = build_graph_for_category(entity_name)
    else
      node = build_graph_for_article(entity_name)
    end

    node.score_informations(name_service)

    node.information_nodes.each do |information_node|
      cyc_name = information_node.best_candidate.cyc_term(name_service).to_ruby.to_s
      output << [prefix+node.name, information_node.name, information_node.best_candidate.cyc_id, cyc_name, information_node.best_candidate.score.max_value, information_node.best_candidate.score.count, information_node.best_candidate.score.value]
    end

  end
end

#TODO category names prefixed
#TODO parallel
#TODO jak ujednolicic score dla kategorii i artykulow?
#TODO jezeli min nie potrzebne to nieliczyc - znacznie przypspieszy


# posortowac wezly
# przypisac i przekalkulowac zalezne
# PRZYPISANIE może tylko zmneijszać wynik, wiec zamiast kalkulacji oznaczyc jako do przeliczenia
#napotykając węzeł do przeliczenia trzeba zaktualizować i wrzucić w odpowiednie meijsce kolejki