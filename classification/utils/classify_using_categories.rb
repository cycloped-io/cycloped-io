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
  banner "#{$PROGRAM_NAME} -d db -f mapping.csv -o classification.csv\n" +
    "Assign types to articles based on the mapping between categories and Cyc concepts."

  on :d=, :database, "Rod database", required: true
  on :f=, :input, "Input file with category mapping (CSV)", required: true
  on :o=, :output, "Output file with the classification", required: true
  on :a=, :articles, "List of articles to classify (CSV)"
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

mapping = {}
CSV.open(options[:input],"r:utf-8") do |input|
  input.with_progress do |category_name,*tuple|
    mapping[category_name] = tuple
  end
end

total = 0
classified = 0
CSV.open(options[:output],"w:utf-8") do |output|
  if options[:articles]
    Progress.start(`wc -l #{options[:articles]}`.to_i)
    CSV.open(options[:articles]) do |input|
      input.each do |title,*rest|
        Progress.step(1)
        row = [title]
        concept = Concept.find_by_name(title)
        next if concept.nil?
        total += 1
        concept.categories.each do |category|
          next unless mapping.has_key?(category.name)
          row.concat(mapping[category.name])
        end
        if row.size > 1
          output << row
          classified += 1
        end
      end
    end
    Progress.stop
  else
    Progress.start(Concept.count)
    Concept.each do |concept|
      Progress.step(1)
      row = [concept.name]
      total += 1
      concept.categories.each do |category|
        next unless mapping.has_key?(category.name)
        row.concat(mapping[category.name])
      end
      if row.size > 1
        output << row
        classified += 1
      end
    end
    Progress.stop
  end
end
puts "classfied/total #{classified}/#{total}/%.1f" % [classified/total.to_f*100]

Database.instance.close_database
