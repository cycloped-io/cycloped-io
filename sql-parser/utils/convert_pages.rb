#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
$:.unshift "lib"
require 'sql/insert_parser'
require 'sql/schema_parser'
require 'sql/reader'
require 'slop'
require 'csv'
require 'yaml'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f file.sql -o output.csv [-c config.en.yml]\n" +
    "Parse SQL page file."
  on :f=, :input, "SQL file to parse", required: true
  on :o=, :output, "CSV output file", required: true
  on :c=, :config, "YAML file with language specific config"
end

begin
  options.parse
rescue Slop::MissingOptionError => e
  puts e
  puts options
  exit
end

if options[:config]
  disambiguation_mark = YAML.load_file(options[:config])[:disambiguation] || "disambiguation"
else
  disambiguation_mark = "disambiguation"
end

DISAMBIGUATION = /\(#{disambiguation_mark}\)/

File.open(options[:input],"r:utf-8") do |input|
  CSV.open(options[:output],"w:utf-8") do |output|
    SQL::Reader.new(input).each_tuple do |tuple|
      begin
        # Wikipedia namespaces
        # http://en.wikipedia.org/wiki/Wikipedia%3ANamespace
        case tuple[:page_namespace]
        when '0'
          type = '0' # article
	when '10'
	  type = '4' # template
	when '14'
	  type = '1' # category
        else
          next
        end
	if tuple[:page_is_redirect] == '1'
	  type = '2' # redirect
	elsif tuple[:page_title].match(DISAMBIGUATION)
	  type = '3' # disambiguation
	end
	title = tuple[:page_title].tr("_"," ")
        output << [tuple[:page_id],title,type,0,tuple[:page_len]]
      rescue Interrupt
        puts
        break
      end
    end
  end
end
