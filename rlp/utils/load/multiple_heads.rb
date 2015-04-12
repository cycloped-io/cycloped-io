#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'slop'
require 'rlp/wiki'
require 'progress'
require 'csv'
include Rlp::Wiki

# Script for loading redirects.

options = Slop.new do
  banner "Usage: #{$PROGRAM_NAME} -d db_path -w data_path\n" +
    "Load between concepts and their eponymous categories."

  on 'd', 'database', 'Database path', argument: :mandatory, required: true
  on 'f', 'input', 'Input file with parsed heads', argument: :mandatory, required: true
end
begin
  options.parse
rescue Slop::MissingOptionError
  puts options
  exit
end

total = 0
multiple = 0
single = 0
Database.instance.open_database(options[:database],:readonly => false)
Progress.start(`wc -l #{options[:input]}`.to_i)
CSV.open("#{options[:input]}","r:utf-8") do |input|
  input.each do |category_id,name,*heads|
    Progress.step(1)
    begin
      total += 1
      category = Category.find_by_wiki_id(category_id.to_i)
      next if category.nil?
      if heads.size == 1
        category.parsed_head = heads.first
        single += 1
      elsif heads.size > 1
        category.parsed_heads = heads
        multiple += 1
      else
        next
      end
      category.plural_head = true
      category.store
    rescue Interrupt
      puts
      break
    rescue Exception => ex
      puts ex
      puts ex.backtrace[0..3]
    end
  end
end
Database.instance.close_database
Progress.stop
puts "single/multi/saved/total #{single}/#{multiple}/#{single+multiple}/#{total}"
