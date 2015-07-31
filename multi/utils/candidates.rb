#!/usr/bin/env ruby
# encoding: utf-8


require 'bundler/setup'
$:.unshift "../category-mapping/lib"
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
  banner "#{$PROGRAM_NAME}\n" +
             "Assign term candidates to phrases."

  on :h=, :host, "Cyc host", default: 'localhost'
  on :p=, :port, "Cyc port", as: Integer, default: 3601
  on :c=, :"category-filters", "Filters for categories: c - collection, s - most specific,\n" +
            "n - noun, r - rewrite of, l - lower case, f - function, c|i - collection or individual, b - black list", default: 'c:r:f:l:d'
  on :g=, :"genus-filters", "Filters for genus proximum types: (as above)", default: 'c:r:f:l:d'
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

black_list_reader = Mapping::BlackListReader.new(options[:"black-list"])
name_service = Mapping::Service::CycNameService.new(cyc)
filter_factory = Mapping::Filter::Factory.new(cyc: cyc, black_list: black_list_reader.read)
term_provider = Mapping::TermProvider.
    new(cyc: cyc, name_service: name_service,
        category_filters: filter_factory.filters(options[:"category-filters"]),
        genus_filters: filter_factory.filters(options[:"genus-filters"]))


include Rlp::Wiki
Database.instance.open_database(options[:database] || '../../en-2013/')


filters = filter_factory.filters(options[:"genus-filters"])

last = nil
CSV.open('phrase_candidates.csv') do |input|
  input.with_progress do |row|
    last = row.first
  end
end

# last='Discworld games'
p last

omit=true
CSV.open('phrase_candidates.csv', 'a') do |output|
  CSV.open('phrases.csv') do |input|
    input.with_progress do |row|
      phrase = row.first

      if last.nil? || phrase==last
        omit=false
        if phrase==last
          next
        end
      end
      next if omit

      begin
        candidates = term_provider.candidates_for_name(phrase, filters)
      rescue NoMethodError
        p phrase
        candidates = []
      end

      output << [phrase]+candidates.map { |candidate| [candidate.id,candidate.name] }.flatten
    end
  end
end

