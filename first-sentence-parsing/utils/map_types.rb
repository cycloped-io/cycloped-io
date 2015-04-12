#!/usr/bin/env ruby

require 'bundler/setup'
require 'slop'
require 'progress'
require 'rlp/wiki'
require 'cycr'
require 'colors'
require 'csv'
require 'set'
require 'rod/rest'
$:.unshift '../category-parsing/lib'
$:.unshift '../category-mapping/lib'
require 'syntax'
require 'nouns/nouns'
require 'mapping'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -o mapping.csv [-p port] [-h host] [-c c:r] [-d database]\n"+
             "Map Wikipedia articles types (genus proximum) to Cyc terms."

  on :d=, :database, "ROD database with Wikipedia data", required: true
  on :o=, :output, "Output mapping file", required: true
  on :p=, :port, "Cyc port", as: Integer, default: 3601
  on :h=, :host, "Cyc host", default: 'localhost'
  on :x=, :offset, "Article offset (skip first n concepts)", as: Integer, default: 0
  on :l=, :limit, "Article limit (limit processing to n articles)", as: Integer
  on :c=, :"category-filters", "Filters for categories: c - collection, s - most specific,\n" +
    "n - noun, r - rewrite of, l - lower case, f - function, c|i - collection or individual, b - black list"
  on :g=, :"genus-filters", "Filters for genus proximum types: (as above)"
  on :b=, :"black-list", "File with black list of Cyc abstract types"
  on :s=, :services, "File with addresses of ROD-rest services"
  on :v, :verbose, "Run the script in verbose mode"
  on :V, :talkative, "Display debug messages"
  on :S=, :"selected-articles", "File with names of selected articles to be mapped (CSV, first column)"
end

begin
  options.parse
rescue
  puts options
  exit
end

include Rlp::Wiki

cyc = Cyc::Client.new(port: options[:port], host: options[:host], cache: true)
black_list_reader = Mapping::BlackListReader.new(options[:"black-list"])
name_service = Mapping::Service::CycNameService.new(cyc)
filter_factory = Mapping::Filter::Factory.new(cyc: cyc, black_list: black_list_reader.read)
term_provider = Mapping::TermProvider.
  new(cyc: cyc, name_service: name_service,
      category_filters: filter_factory.filters(options[:"category-filters"]),
      genus_filters: filter_factory.filters(options[:"genus-filters"]))

services = {}
if options[:services]
  YAML.load_file(options[:services]).each do |id,specification|
    connection = Faraday.new(url: "http://#{specification[:host]}:#{specification[:port]}"){|c| c.adapter(:net_http_persistent)}
    services[id] = Rod::Rest::Client.new(http_client: connection,proxy_cache: nil)
  end
end
context_provider = Mapping::ContextProvider.new(rlp_services: services)

black_list = []
if options[:"black-list"]
  black_list = Set.new(File.readlines(options[:"black-list"]).map(&:chomp).map(&:to_sym))
end

merger = Mapping::Service::TermMerger.new(cyc: cyc)
mapping_service = Mapping::Service::GenusProximumMappingService.
  new(term_provider: term_provider, context_provider: context_provider, cyc: cyc, verbose: options[:verbose], talkative: options[:talkative])

Database.instance.open_database(options[:database])

CSV.open(options[:output],"w") do |output|
  if options[:"selected-articles"]
    articles = []
    CSV.open(options[:"selected-articles"],"r:utf-8"){|i| i.each {|name,*| articles << name } }
    Progress.start(articles.size) unless options[:verbose]
    articles.uniq.each do |article_name|
      article = Concept.find_by_name(article_name)
      Progress.step(1) unless options[:verbose]
      next if article.nil?
      begin
        output << mapping_service.candidates_for_article(article)
      rescue Interrupt
        puts
        break
      rescue Exception => ex
        STDERR.puts "Error for #{article}"
        STDERR.puts ex
        STDERR.puts ex.backtrace
      end
    end
  else
    skip_name = nil
    if File.exist?(options[:output])
      CSV.open(options[:output]) do |input|
        input.each do |row|
          skip_name = row.first
        end
      end
    end
    if skip_name
      skip_offset = Concept.find_by_name(skip_name).wiki_id
    end

    offset = options[:offset]
    if options[:limit]
      entities_count = options[:limit]
      limit = options[:limit] + offset
    else
      limit = Concept.count
      entities_count = limit - offset
    end
    puts "count %i offset %i limit %i" % [entities_count,offset,limit]

    Progress.start(entities_count) unless options[:verbose]
    Concept.each.with_index do |article,index|
      next if index < offset
      break if index >= limit
      Progress.step(1) unless options[:verbose]
      next if article.types.nil?
      next if skip_offset && article.wiki_id <= skip_offset
      begin
        output << mapping_service.candidates_for_article(article)
      rescue Interrupt
        puts
        break
      rescue Exception => ex
        STDERR.puts "Error for #{article}"
        STDERR.puts ex
        STDERR.puts ex.backtrace
      end
    end
  end
end
Progress.stop unless options[:verbose]
Database.instance.close_database
