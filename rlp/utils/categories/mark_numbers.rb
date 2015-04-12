#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'slop'
require 'rlp/wiki'
require 'progress'

options = Slop.new do
  banner "Usage: #{$PROGRAM_NAME} -d database\n" +
    "Mark categories containing numbers."

  on 'd', 'db_path', 'ROD Database path', argument: :mandatory, required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

include Rlp::Wiki

Database.instance.open_database(options[:db_path],readonly: false)
Progress.start(Category.count)
Category.each do |category|
  Progress.step(1)
  category.contains_number! if category.name =~ /\d/
end
Progress.stop
Database.instance.close_database
