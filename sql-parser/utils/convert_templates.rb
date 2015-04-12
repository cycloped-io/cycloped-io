#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
$:.unshift "lib"
require 'sql/insert_parser'
require 'sql/schema_parser'
require 'sql/reader'
require 'slop'
require 'csv'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f file.sql -o output.csv\nParse SQL template links file."
  on :f=, :input, "SQL file to parse", required: true
  on :o=, :output, "CSV output file", required: true
end

begin
  options.parse
rescue Slop::MissingOptionError => e
  puts e
  puts options
  exit
end
begin
File.open(options[:input],"r:utf-8") do |input|
  CSV.open(options[:output],"w:utf-8") do |output|
    SQL::Reader.new(input).each_tuple do |tuple|
      begin
        next unless tuple[:tl_namespace] == "10"
        title = tuple[:tl_title].tr("_"," ")
        output << [tuple[:tl_from],title]
      rescue Interrupt
        puts
        break
      rescue Exception => ex
        puts ex
      end
    end
  end
end

puts "Sorting"
end
path = options[:output]
`sort -n #{path} -T #{File.dirname(path)} > #{path}.sorted`
puts "Merging"
last_id = nil
last_ids = []
CSV.open("#{path}.sorted") do |input|
  CSV.open("#{path}.merged","w") do |output|
    input.each do |id,*rest|
      if id == last_id
        last_ids.concat(rest)
      else
        output << last_ids.unshift(last_id)
        last_ids = rest
      end
      last_id = id
    end
    output << last_ids.unshift(last_id)
  end
end
puts "Clean up"
`rm #{path}.sorted`
`mv #{path}.merged #{path}`
