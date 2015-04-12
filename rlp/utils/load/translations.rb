#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'slop'
require 'rlp/wiki'
require 'progress'
require 'csv'
include Rlp::Wiki

# Script for loading translations

options = Slop.new do
  banner "Usage: redirects.rb -d db_path -w data_path -l lang1:lang2:lang3...\n" +
    "Load translations for articles and categories."

  on :d=, :db_path, 'Database path', required: true
  on :w=, :data_path, 'CSV files with Wikipedia data path', required: true
  on :l=, :languages, 'Languages selected for translation loading', required: true
end
begin
  options.parse
rescue Slop::MissingOptionError
  puts options
  exit
end

db_path = options[:db_path]
data_path = options[:data_path]
languages = options[:languages].split(":")

Database.instance.open_database(db_path,:readonly => false)

csv = CSV
missing = File.open("log/missing_trans.log","w")

total = 0
linked = 0
Progress.start(`wc -l  #{data_path}/translations.csv`.to_i)
open("#{data_path}/translations.csv","r:utf-8") do |file|
  file.each.with_index do |line,index|
    begin
      Progress.step(1)
      page_id, *translations = csv.parse(line).first
      page_id = page_id.to_i
      page = Concept.find_by_wiki_id(page_id)
      if page.nil?
        page = Category.find_by_wiki_id(page_id)
        if page.nil?
          missing.puts "#{page_id}"
          next
        end
      end
      translations.each_slice(2) do |language,value|
        next unless languages.include?(language)
        total += 1
        translation = Translation.new(:language => language,
                                      :value => value,
                                      :page => page)
        translation.store
        page.translations << translation
        linked += 1
      end
      page.store(false)
    rescue Interrupt
      puts
      break
    rescue Exception => ex
      puts line
      puts ex
    end
  end
end
Progress.stop
Database.instance.close_database

missing.close

puts "Linked translations: #{linked}/#{total}"
