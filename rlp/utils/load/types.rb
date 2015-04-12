#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
require 'progress'
require 'set'
require 'csv'
require 'slop'

include Rlp::Wiki

opts = Slop.new do
  banner "Usage: #{$PROGRAM_NAME} -w data_path\n" +
             'Load first sentence definitions.'

  on :d=, :db_path, 'Database path', required: true
  on :w=, :data_path, 'Path to CSV file with types form first sentence', required: true
end
begin
  opts.parse
rescue Slop::MissingOptionError
  puts opts
  exit
end

db_path = opts[:db_path]
data_path = opts[:data_path]

Database.instance.open_database(db_path, :readonly => false)

CSV.open(data_path, 'r:utf-8') do |csv|
  csv.with_progress do |article_name, sentence, parsed, dependencies, *types|
    concept = Concept.find_by_name(article_name)
    next if concept.nil?
    concept.types = types.each_slice(2).to_a
    concept.store(false)
  end
end


Database.instance.close_database