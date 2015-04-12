#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
$:.unshift "lib"
require 'slop'
require 'csv'
require 'cycr'
require 'progress'

require 'rlp/wiki'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -d database -f test_set.csv -o filtered_test_set.csv\n" +
             "Filter regular articles."

  on :d=, :database, "ROD database", required: true
  on :f=, :mapping, "File with classification test set", required: true
  on :o=, :output, "Output file", required: true
end

begin
  options.parse
rescue Exception
  puts options
  exit
end

include Rlp::Wiki

Database.instance.open_database(options[:database])

new_deletion = ['(16433) 1988 VX2', '(16473) 1990 QF2', '(18326) 1985 CV1', '(18342) 1989 ST9', '(19261) 1995 MB', '(201500) 2003 LV2', '(31121) 1997 RD10', '7828 Noriyositosi', 'Cambia Perú', 'Cambrian James', 'Dan Walker', 'Edward Coke (politician)', 'Far from Home (album)', 'Head of talus', 'Irtahlak Albi', 'Justin Robbins', 'Kevin Price', 'MÄR Omega', 'Mia Presley', 'Richard Goddard', 'Samuel Palermo', 'The Rajah', 'Thomas Smith (footballer)', 'William Holbech']

CSV.open(options[:output], "w:utf-8") do |output|
  CSV.open(options[:mapping], "r:utf-8") do |input|
    input.with_progress do |row|
      wiki_name = row.first
      article = Concept.find_with_redirect(wiki_name)
      if article.nil? or new_deletion.include?(wiki_name)
        p wiki_name
        next
      end
      if article.regular?
        output << row
      end
    end
  end
end

Database.instance.close_database
