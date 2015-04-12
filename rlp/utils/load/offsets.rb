#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
require 'slop'
require 'progress'
require 'csv'

include Rlp::Wiki

options = Slop.new do
  banner "#{$PROGRAM_NAME} -d db_path -w data_path\n" +
    "Load offsets and article lengths to ROD database"

  on :d=, :db_path, "ROD database", required: true
  on :w=, :data_path, "File with offsets and lengths (CSV)", required: true
end

begin
  options.parse
rescue
  puts options
  exit
end


Database.instance.open_database(options[:db_path],:readonly => false)

csv = CSV

Progress.start(`wc -l #{options[:data_path]}/offsets.csv`.to_i)
total = 0
offsets = 0
CSV.open("#{options[:data_path]}/offsets.csv") do |input|
  input.each do |page_id,offset,length|
    Progress.step(1)
    page_id = page_id.to_i
    offset = offset.to_i
    length = length.to_i
    begin
      total += 1
      page = Concept.find_by_wiki_id(page_id)
      if page.nil?
        page = Category.find_by_wiki_id(page_id)
      end
      if page.nil?
        page = Redirect.find_by_wiki_id(page_id)
      end
      if page.nil?
        next
      end
      page.text_offset = offset
      page.text_length = length
      page.store(false)
      offsets += 1
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
puts "Offsets: #{offsets}/#{total}"
