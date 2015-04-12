#!/usr/bin/env ruby
# encoding: utf-8

# This script matches the occurrences with concepts.
#
# This is not done in the anchor script, since we would
# have to keep a set of modified concepts which would be
# very large.

require 'slop'
require 'bundler/setup'
require 'rlp/wiki'
require 'hadoop/csv'
require 'progress'
require 'set'
include Rlp::Wiki

opts = Slop.new do
  banner 'Usage: occurences.rb -d db_path -w data_path'

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

csv = Hadoop::Csv.new
Database.instance.open_database(db_path, :readonly => false)

missing_pages = File.open("log/missing_occurrence_pages.log","w")
total = 0
occurrence_count = 0
open("#{data_path}/pageLabel.csv","r:utf-8") do |file|
  file.with_progress.each_with_index do |line,index|
    #puts "#{index} #{Time.now}" if index % 10000 == 0
    begin
      wiki_id, occurrences = csv.parse(line)
      concept = Concept.find_by_wiki_id(wiki_id)
      next if concept.nil?
      occurrences.each do |value, count, distinct, from_redirect, _, _|
        total += 1
        anchor = Anchor.find_by_value(value)
        next if anchor.nil?
        occurrence = anchor.occurrences.find{|o| o.concept == concept }
        next if occurrence.nil?
        concept.occurrences << occurrence
        occurrence_count += 1
      end
      concept.store
    rescue Exception => ex
      puts line
      puts ex
    end
  end
end
Database.instance.close_database
missing_pages.close

puts "Anchors #{occurrence_count}/#{total}"
