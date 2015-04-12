#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
require 'progress'
require 'csv'
require 'slop'
require 'cycr'
require 'set'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -m data/reference.csv -o updated.csv\n" +
    'Correct article names using redirects.'

  on :m=, :verification, 'Manual verification', required: true
  on :o=, :output, 'Updated manual verification', required: true
  on :d=, :database, "Rod database", default: '../rlp/data/en-2013'
  on :x, :"ignore-missing", "Ignore articles that are not present in the database"
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

include Rlp::Wiki
Database.instance.open_database(options[:database])

redirected_count = 0
missing_count = 0
present_count = 0
CSV.open(options[:output], "w") do |output|
  CSV.open(options[:verification], "r:utf-8") do |verification_csv|
    verification_csv.with_progress do |name, *rest|
      concept = Concept.find_by_name(name)
      if concept
        output << [name, *rest]
        present_count += 1
      else
        redirected = Concept.find_with_redirect(name)
        if redirected
          #puts 'REDIRECTED: '+redirected.name
          output << [redirected.name, *rest]
          redirected_count += 1
        else
          #puts 'DOES NOT EXIST: '+name
          output << [name, *rest] unless options[:"ignore-missing"]
          missing_count += 1
        end
      end
    end
  end
end

puts "missing/redirected/present %i/%i/%i" % [missing_count,redirected_count,present_count]
