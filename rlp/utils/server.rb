#!/usr/bin/env ruby
# encding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
require 'rod/rest'
require 'slop'

options = Slop.new do
  banner "#$PROGRAM_NAME -d database [-p port]" +
    "Start REST API for the ROD database at the given port."

  on :d=, :database, "ROD database", required: true
  on :p=, :port, "API port", as: Integer
  on :e=, :environment, "Running environment (default: development)", default: "development"
end

begin
  options.parse
rescue
  puts options
  exit
end

include Rlp::Wiki

Database.instance.open_database(options[:database])
Rod::Rest::API.start_with_database(Database.instance,{},port: options[:port],environment: options[:environment])

at_exit do
  Database.instance.close_database
end
