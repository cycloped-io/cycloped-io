#!/usr/bin/env ruby
# encding: utf-8

require 'bundler/setup'
require 'rod/rest'
require 'irb'
require 'slop'

options = Slop.new do
  banner "#$PROGRAM_NAME [-p port] [-h host]" +
    "Start client of ROD REST api with a console"

  on :p=, :port, "Port of the REST API", as: Integer, default: 4567
  on :h=, :host, "Host of the REST API", default: "localhost"
end

begin
  options.parse
rescue
  puts options
  exit
end

include Rlp::Wiki

at_exit do
  url = "http://#{options[:host]}:#{options[:port]}"
  puts "Starting client for #{url}"
  http_client = Faraday.new(url)
  $client = Rod::Rest::Client.new(http_client: http_client)
  ARGV.clear
  IRB.start
end

