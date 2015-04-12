#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'slop'
require 'rlp/wiki'
require 'progress'
require 'set'
require 'csv'
require 'colors'
require 'progress'
include Rlp::Wiki

options = Slop.new do
  banner "Usage: #{$PROGRAM_NAME} -d db_path -f parses\nLoad category name parses to the DB."

  on 'd', 'db_path', 'Database path', argument: :mandatory, required: true
  on 'f', 'input_file', 'CSV with parsed categories', argument: :mandatory, required: true
end
begin
  options.parse
rescue Slop::MissingOptionError
  puts options
  exit
end

db_path = options[:db_path]
input_file = options[:input_file]
Database.instance.open_database(db_path,:readonly => false)
#Progress.start(`wc -l #{input_file}`.to_i)
CSV.open(input_file, 'r:utf-8') do |input|
  #input.each_with_index do |(name,full_parse,head_parse,head,number),index|
  Progress.start(input.stat.size)
  input.each_with_index do |(category_name,preprocessed_category_name,full_parse,dependency,head_parse,head,plural),index|  
    
    
    begin
      Progress.set(input.pos)
      full_parse.chomp!
      category_name.force_encoding('utf-8')
      category = Category.find_by_name(category_name)
      category.parsed_name = full_parse
      category.parsed_head = head_parse
      category.plural_head = plural == 'true'
      category.store(false)
    rescue Interrupt
      break
    rescue Exception => ex
      puts ex
      puts category_name
    end
  end
end
Progress.stop
Database.instance.close_database
