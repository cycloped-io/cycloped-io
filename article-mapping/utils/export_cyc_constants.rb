#!/usr/bin/env ruby
# encding: utf-8

require 'bundler/setup'
require 'progress'
require 'csv'
require 'slop'
require 'colors'
require 'cycr'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -o constants.csv [-h host] [-p port] \n" +
    "Export Cyc constants"

  on :o=, :output, "Output file with full stats", required: true
  on :h=, :host, "Cyc host", default: "localhost"
  on :p=, :port, "Cyc port", default: 3601, as: Integer
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

client = Cyc::Client.new(port: options[:port],host: options[:host])
CSV.open(options[:output],"w") do |output|
  ('a'..'z').each do |letter|
    client.constant_complete(letter).each do |name|
      next unless Symbol === name
      output << [name]
    end
  end
end
