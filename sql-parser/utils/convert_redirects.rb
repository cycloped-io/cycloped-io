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
  banner "#{$PROGRAM_NAME} -f file.sql -o output.csv\nParse SQL redirects file."
  on :f=, :input, "SQL file to parse", required: true
  on :t=, :target_by_source, "CSV output file organized from redirect source to target article", required: true
  on :s=, :source_by_target, "CSV output file organized from article to its redirects", required: true
end

begin
  options.parse
rescue Slop::MissingOptionError => e
  puts e
  puts options
  exit
end

begin
  input = File.open(options[:input],"r:utf-8")
  target_by_source = CSV.open(options[:target_by_source],"w:utf-8")
  source_by_target = CSV.open(options[:source_by_target],"w:utf-8")

  SQL::Reader.new(input).each_tuple do |tuple|
    begin
      case tuple[:rd_namespace]
      when '0'
        type = '0' # article
      when '14'
        type = '1' # category
      else
        next
      end
      title = tuple[:rd_title].tr("_"," ")
      target_by_source << [tuple[:rd_from],type,title,
                           tuple[:rd_fragment],tuple[:rd_interwiki]]
      source_by_target << [title,type,tuple[:rd_from]]
    rescue Interrupt
      puts
      break
    rescue Exception => ex
      puts ex
    end
  end
ensure
  input.close
  target_by_source.close
  source_by_target.close
end


puts "Sorting"
path = options[:source_by_target]
`sort -n #{path} -T #{File.dirname(path)} > #{path}.sorted`
puts "Merging"
last_article = nil
last_type = nil
last_ids = []
CSV.open("#{path}.sorted") do |input|
  CSV.open("#{path}.merged","w") do |output|
    input.each do |article,type,redirect_id|
      if article == last_article
        last_ids << redirect_id
      else
        last_ids.unshift(last_type)
        last_ids.unshift(last_article)
        output << last_ids unless last_article.nil?
        last_ids = [redirect_id]
      end
      last_article = article
      last_type = type
    end
    last_ids.unshift(last_type)
    last_ids.unshift(last_article)
    output << last_ids
  end
end
puts "Clean up"
`rm #{path}.sorted`
`mv #{path}.merged #{path}`
