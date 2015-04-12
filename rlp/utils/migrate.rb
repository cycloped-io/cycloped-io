#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'slop'
require 'rlp/wiki'

options = Slop.new do
  banner "Usage: #{$PROGRAM_NAME} -d db_path\nMigrate the schema used in the DB to match the Ruby code."

  on 'd', 'db_path', 'Database path', argument: :mandatory, required: true
end
begin
  options.parse
rescue Slop::MissingOptionError
  puts options
  exit
end

$ROD_DEBUG = true
include Rlp::Wiki
Database.instance.migrate_database(options[:db_path])
