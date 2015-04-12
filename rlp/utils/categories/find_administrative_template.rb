#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'slop'

options = Slop.new do
  banner "Usage: #{$PROGRAM_NAME} -f template_dump\nFind categories with administrative template."

  on :f=, 'template-dump', 'File containing template links extracted from Wikipedia SQL dumps', required: true
  on :o=, 'output', 'Output file with ids of categories which include the administrative template', required: true
end
begin
  options.parse
rescue Slop::MissingOptionError
  puts options
  exit
end

path = options[:"template-dump"]

puts "Finding templates"
puts `grep 'Wikipedia category' #{path} > #{path}.admin`
unless $?.to_i == 0
  puts "Error in grep"
  exit($?.to_i)
end

puts "Extracting ids"
puts `awk 'BEGIN { FS = "," }; { print $1 }' #{path}.admin > #{options[:output]}`
unless $?.to_i == 0
  puts "Error in awk"
  exit($?.to_i)
end

`rm #{path}.admin`
