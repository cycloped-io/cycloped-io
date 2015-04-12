#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'slop'
require 'rlp/wiki'
require 'csv'
require 'progress'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -d db_path -f categories_ids.txt -o links.csv [-w dump.xml]\n" +
    "Export eponymous category links from Wikipedia XML dump"

  on :d=, :db_path, "Path to ROD database", required: true
  on :f=, :input, "File with ids of categories with eponymous template", required: true
  on :o=, :output, "File with ids of categories and the names of corresponding articles", required: true
  on :w=, :dump, "File with Wikipedia dump (pages-articles). Might be provided by RLP_WIKI_PAGES env. variable"
end

begin
  options.parse
rescue
  puts options
  exit
end

if !ENV['RLP_WIKI_PAGES'] && !options[:dump]
  puts "Neither RLP_WIKI_PAGES nor -w option supplied"
  puts options
  exit
end

include Rlp::Wiki

Page.path = options[:dump] || ENV['RLP_WIKI_PAGES']

Database.instance.open_database(options[:db_path])
total = `wc -l #{options[:input]}`.to_i
Progress.start(total)
extracted = 0

File.open(options[:input]) do |input|
  CSV.open(options[:output],"w") do |output|
    input.each do |line|
      Progress.step(1)
      category = Category.find_by_wiki_id(line.to_i)
      next if category.nil?
      matched = category.contents.match(/{{(?:Cat main|Main)(?:\|(.*?))?}}/)
      next unless matched
      if matched[1]
        output << [line.chomp,matched[1]]
      else
        output << [line.chomp,category.name]
      end
      extracted += 1
    end
  end
end

puts "extracted/total #{extracted}/#{total}"

Progress.stop
Database.instance.close_database
