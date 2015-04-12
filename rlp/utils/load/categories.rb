#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
require 'progress'
require 'set'
require 'csv'
require 'slop'

include Rlp::Wiki

# Script for linking pages with their categories.

opts = Slop.new do
  banner 'Usage: categories.rb -d db_path -w data_path'

  on 'd', 'db_path', 'Database path', argument: :mandatory, required: true
  on 'w', 'data_path', 'Path to dir with extracted data', argument: :mandatory, required: true
end
begin
  opts.parse
rescue Slop::MissingOptionError
  puts opts
  exit
end

db_path = opts[:db_path]
data_path = opts[:data_path]

missing_parents = File.open("log/missing_parents.log","w")
missing_children = File.open("log/missing_children.log","w")

csv = CSV
[
  [Concept,Category,"articleParents",:categories],
  [Category,Concept,"childArticles",:concepts],
  [Category,Category,"categoryParents",:parents],
  [Category,Category,"childCategories",:children],
].each do |primary_class,secondary_class,file_name,method_name|
  Database.instance.open_database(db_path,:readonly => false)
  total = 0
  linked = 0
  puts "Processing #{file_name}"
  open("#{data_path}/#{file_name}.csv","r:utf-8") do |file|
    Progress.start(file.stat.size)
    file.each_with_index do |line,index|
      Progress.set(file.pos)
      next if line =~ /^\s*$/
      begin
        primary_element, *secondary_elements = csv.parse(line).first
        if file_name =~ /^child/
          primary = primary_class.find_by_name(primary_element)
        else
          primary = primary_class.find_by_wiki_id(primary_element.to_i)
        end
        if primary.nil?
          total += secondary_elements.size
          missing_children.puts "#{primary_element}"
          next
        end
        primary.send("#{method_name}=",[])
        secondary_elements.each do |secondary_element|
          total += 1
          if file_name =~ /^child/
            secondary = secondary_class.find_by_wiki_id(secondary_element.to_i)
          else
            secondary = secondary_class.find_by_name(secondary_element)
          end
          if secondary.nil?
            missing_parents.puts "#{secondary_element}"
            next
          end
          primary.send(method_name) << secondary
          linked += 1
        end
        primary.store(false)
      rescue Exception => ex
        puts line
        puts ex
      end
    end
    Progress.stop
  end
  puts "Links created #{file_name} #{linked}/#{total}"
  Database.instance.close_database
end

missing_parents.close
missing_children.close
