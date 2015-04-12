#!/usr/bin/env ruby
# encoding: utf-8

# This script loads the the anchors and their occurrences to the database.
# The back-link (from concept to occurrence) is created in the occurrences.rb
# script.

require 'slop'
require 'bundler/setup'
require 'rlp/wiki'
require 'hadoop/csv'
require 'progress'
require 'set'
include Rlp::Wiki


opts = Slop.new do
  banner "Usage: #{$PROGRAM_NAME} -d db_path -w data_path\n" +
    "Loads anchors (names of links to Wikipedia articles) and \n" +
    "occurrences (relationships between anchors and articles).\n" +
    "Relatioships between concepts and occurrences are loded in separate script"

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

missing_pages = File.open("log/missing_anchor_pages.log","w")
total = 0
anchor_count = 0
occurrence_count = 0
open("#{data_path}/label.csv","r:utf-8") do |file|
  file.with_progress.each_with_index do |line,index|
    #puts "#{index} #{Time.now}" if index % 10000 == 0
    begin
      total += 1
      value, linked_count, distinct_linked_count, unlinked_count, distinct_unlinked_count,
        occurrences = csv.parse(line)
      anchor = Anchor.new(:value => value, :linked_count => linked_count,
                          :unlinked_count => unlinked_count)
      next unless anchor.valid?
      anchor_count += 1

      occurrences.each do |wiki_id, count, distinct, from_redirect, from_x|
        next if count == 0
        concept = Concept.find_with_redirect_id(wiki_id)
        if concept.nil?
          missing_pages.puts wiki_id.to_s
          next
        end
        occurrence = Occurrence.new(:concept => concept, :anchor => anchor,
                                    :count => count)
        occurrence.store
        anchor.occurrences << occurrence
      end
      anchor.store(false)
    rescue Interrupt
      puts
      break
    rescue Exception => ex
      puts line
      puts ex
    end
  end
end
Database.instance.close_database
missing_pages.close
puts "Anchors #{anchor_count}/#{total}"
