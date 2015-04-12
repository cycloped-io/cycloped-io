#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
require 'progress'
require 'set'
require 'csv'
require 'slop'

opts = Slop.new do
  banner "Usage: #{$PROGRAM_NAME} -d db_path -w data_path"

  on :d=, 'db_path', 'Database path', required: true
  on :w=, 'data_path', 'Path to CSV file with semantic parents', required: true
end
begin
  opts.parse
rescue Slop::MissingOptionError
  puts opts
  exit
end

include Rlp::Wiki
Database.instance.open_database(opts[:db_path], :readonly => false)

CSV.open(opts[:data_path]) do |file_parents|
  file_parents.with_progress do |row|
    category_id, *parent_ids = row
    category = Category.find_by_wiki_id(category_id.to_i)
    category.semantic_parents = parent_ids.map { |id| Category.find_by_wiki_id(id.to_i) }
    category.store(false)
  end
end


Database.instance.close_database