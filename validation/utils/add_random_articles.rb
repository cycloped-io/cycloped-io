#!/usr/bin/env ruby
# encoding: utf-8


require 'bundler/setup'
require 'slop'
require 'csv'
require 'progress'
require 'colors'
require 'cycr'
require 'set'
require 'rlp/wiki'
$:.unshift "lib"


options = Slop.new do
  banner "#{$PROGRAM_NAME} -d database -v classification.csv -i test_set.csv [-c count]\n" +
             "Add random samples to test set."

  on :d=, :database, "ROD database", required: true
  on :v=, :classification, "Input file with classification", required: true
  on :i=, :input, "Input file with test set", required: true
  on :c=, :count, "Number of concepts to validate", default: 600, as: Integer
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

selected = Set.new
count = 0

CSV.open(options[:input], "r+:utf-8") do |input|
  input.each do |tuple|
    selected << tuple
    count += 1
  end


  if count != selected.size
    p 'Not unique data'
  end

  classification_path = options[:classification]

  IO.popen("shuf \"#{classification_path}\"") do |f|
    f.each do |line|
      row =  CSV.parse_line(line)
      wiki_name = row.shift
      next if selected.include?(wiki_name)
      concept = Concept.find_by_name(wiki_name)
      next if concept.nil?
      next if !concept.regular?
      terms = []
      row.each_slice(3) do |id, name, probability|
        terms << [id, name]
      end
      input << [wiki_name] + terms.sample
      selected << wiki_name
      break if selected.size == options[:count]
    end
  end
end

Database.instance.close_database

