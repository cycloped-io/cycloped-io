#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'slop'
require 'rlp/wiki'
require 'progress'
require 'csv'
include Rlp::Wiki

# Script for loading redirects.

opts = Slop.new do
  banner "Usage: #{$PROGRAM_NAME} -d db_path -w data_path\n" +
    "Load between concepts and their eponymous categories."

  on 'd', 'db_path', 'Database path', argument: :mandatory, required: true
  on 'w', 'data_path', 'WikiMiner files path', argument: :mandatory, required: true
end
begin
  opts.parse
rescue Slop::MissingOptionError
  puts opts
  exit
end

db_path = opts[:db_path]
data_path = opts[:data_path]

total = 0
total_categories = 0
linked = 0
linked_categories = 0
Database.instance.open_database(db_path,:readonly => false)
Progress.start(`wc -l #{data_path}/eponymous.csv`.to_i)
CSV.open("#{data_path}/eponymous.csv","r:utf-8") do |input|
  input.each do |category_id,concept_names|
    Progress.step(1)
    total_categories += 1
    begin
      category = Category.find_by_wiki_id(category_id.to_i)
      next if category.nil?
      linked_categories += 1
      concept_names.split("|").each do |concept_name|
        total += 1
        concept = Concept.find_with_redirect(concept_name)
        next if concept.nil?
        category.eponymous_concepts << concept
        concept.eponymous_categories << category
        concept.store
        linked += 1
      end
      category.store
    rescue Interrupt
      puts
      break
    rescue Exception => ex
      puts "error #{category_id}:#{concept_names}"
      puts ex
      puts ex.backtrace[5]
    end
  end
end
Database.instance.close_database
Progress.stop
puts "Linked concepts: #{linked}/#{total}"
puts "Linked categories: #{linked_categories}/#{total_categories}"
