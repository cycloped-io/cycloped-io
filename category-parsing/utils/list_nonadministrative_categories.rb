#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'slop'
require 'csv'
require 'progress'
require 'rlp/wiki'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -o categories.csv -d database\n" +
             'List non-administrative categories (for Stanford Parser).'

  on :d=, :database, 'Rod database', default: '../rlp/data/en-2013'
  on :o=, :output, 'Prefix of output files', required: true
end

begin
  options.parse
rescue Exception
  puts options
  exit
end

include Rlp::Wiki
Database.instance.open_database(options[:database])

CSV.open(options[:output], 'w') do |output|
  Category.with_progress do |category|
    output << [category.name] if !category.administrative?
  end
end