#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
$:.unshift "lib"
require 'sql/insert_parser'
require 'sql/schema_parser'
require 'sql/reader'
require 'slop'
require 'csv'
require 'zlib'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f file.sql -o output.csv\nParse SQL category-page files."
  on :f=, :input, "SQL file to parse", required: true
  on :o=, :output, "CSV output file prefix", required: true
end

begin
  options.parse
rescue Slop::MissingOptionError => e
  puts e
  puts options
  exit
end

file_names = %w{articleParents childArticles categoryParents childCategories}

files = file_names.map{|name| CSV.open("#{options[:output]}#{name}.csv","w") }
File.open(options[:input],"r:utf-8") do |input|
  SQL::Reader.new(input).each_tuple.with_index do |tuple,index|
    begin
      target = tuple[:cl_to].tr("_"," ")
      if tuple[:cl_type] == "page"
        files[0] << [tuple[:cl_from],target]
        files[1] << [target,tuple[:cl_from]]
      elsif tuple[:cl_type] == "subcat"
        files[2] << [tuple[:cl_from],target]
        files[3] << [target,tuple[:cl_from]]
      else
        next
      end
    rescue Interrupt
      puts
      break
    rescue Exception => ex
      puts ex
      puts ex.backtrace[0..5]
    end
  end
end
files.map(&:close)

file_names.each do |name|
  path = "#{options[:output]}#{name}.csv"
  puts "Processing #{name}"
  puts "Sorting"
  `sort -n #{path} > #{path}.sorted`
  last_id = nil
  last_targets = []
  puts "Merging"
  CSV.open("#{path}.sorted") do |input|
    CSV.open("#{path}.merged","w") do |output|
      input.each do |id,target|
        if id == last_id
          last_targets << target
        else
          output << last_targets.unshift(last_id)
          last_targets = [target]
        end
        last_id = id
      end
      output << last_targets.unshift(last_id)
    end
  end
  puts "Clean up"
  `rm #{path}.sorted`
  `mv #{path}.merged #{path}`
end
