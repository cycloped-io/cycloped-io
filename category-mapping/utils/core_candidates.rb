#!/usr/bin/env ruby

require 'bundler/setup'
$:.unshift 'lib'
require 'slop'
require 'progress'
require 'rlp/wiki'
require 'cycr'
require 'colors'
require 'csv'
require 'set'
require 'rod/rest'
require 'syntax'
require 'mapping'
require 'nouns/nouns'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -o core_candidates.csv -d database_path\n"+
             'Generate candidates for core categories'

  on :d=, :database, 'ROD database with Wikipedia data', required: true
  on :o=, :output, 'Output candidates file', required: true
  on :p=, :port, 'Cyc port', as: Integer, default: 3601
  on :h=, :host, 'Cyc host', default: 'localhost'
  on :c=, :'category-filters', "Filters for categories: c - collection, s - most specific,\n" +
            'n - noun, r - rewrite of, l - lower case, f - function, c|i - collection or individual, b - black list, d - ill-defined', default: 'c:r:f:l:d'
  on :a=, :'article-filters', 'Filters for articles: as above', default: 'c|i:r:f:l:d'
  on :b=, :'black-list', 'File with black list of Cyc abstract types'
  on :v, :verbose, 'Display verbose messages (progress is suppresed)'
  on :V, :talkative, 'Display detailed messages about potential and matched links (isa/genls)'
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

include Rlp::Wiki

cyc = Cyc::Client.new(port: options[:port], host: options[:host], cache: true)
name_service = Mapping::Service::CycNameService.new(cyc)
black_list_reader = Mapping::BlackListReader.new(options[:'black-list'])
filter_factory = Mapping::Filter::Factory.new(cyc: cyc, black_list: black_list_reader.read)
term_provider = Mapping::TermProvider.
    new(cyc: cyc, name_service: name_service,
        category_filters: filter_factory.filters(options[:'category-filters']),
        article_filters: filter_factory.filters(options[:'article-filters']))

Database.instance.open_database(options[:database])

CSV.open(options[:output], 'w') do |output|
  Category.with_progress do |category|
    next unless category.regular?
    next unless category.plural?

    candidate_set = term_provider.core_category_candidates(category)
    candidates = candidate_set.all_candidates.flatten.uniq
    output << [category.name] + candidates.map{|cyc_term| [cyc_term.id, cyc_term.to_ruby.to_s]}.flatten if !candidates.empty?
  end
end

Database.instance.close_database