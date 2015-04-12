#!/usr/bin/env ruby
# encoding: utf-8

require 'slop'
require 'bundler/setup'
require 'rlp/wiki'
require 'hadoop/csv'
require 'progress'
require 'set'
include Rlp::Wiki

opts = Slop.new do
  banner 'Usage: links.rb -d db_path -w data_path -r direction'

  on 'd', 'db_path', 'Database path', argument: :mandatory, required: true
  on 'w', 'data_path', 'WikiMiner files path', argument: :mandatory, required: true
  on 'r', 'direction', 'Links direction', argument: :mandatory, required: true
end
begin 
  opts.parse
rescue Slop::MissingOptionError
  puts opts
  exit
end

db_path = opts[:db_path]
data_path = opts[:data_path]
direction = opts[:direction]


csv = Hadoop::Csv.new

errors = File.open("log/missing_pagelink.log","w")
total = 0
linked = 0

if direction == "in"
  file_name = "pageLinkIn"
  method_name = :linking_concepts
else
  file_name = "pageLinkOut"
  method_name = :linked_concepts
end

Database.instance.open_database(db_path, :readonly => false)
open("#{data_path}/#{file_name}.csv","r:utf-8") do |file|
  file.with_progress.each_with_index do |line,index|
    begin
      concept_id, link_positions = csv.parse(line)
      concept = Concept.find_with_redirect_id(concept_id)
      if concept.nil?
        errors.puts concept_id.to_s
        next
      end
      link_positions.each do |link_id,sentence_positions|
        link = Concept.find_with_redirect_id(link_id)
        total += 1
        if link.nil?
          errors.puts link_id.to_s
          next
        end
        concept.send(method_name) << link
        linked += 1
      end
      concept.store
    rescue Exception => ex
      puts line
      puts ex
      puts ex.backtrace
    end
  end
end
errors.close
Database.instance.close_database

puts "Linked articles #{linked}/#{total}"
