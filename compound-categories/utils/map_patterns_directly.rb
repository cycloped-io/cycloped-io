#!/usr/bin/env ruby

require 'bundler/setup'
$:.unshift "lib"
require 'slop'
require 'progress'
require 'rlp/wiki'
require 'cycr'
require 'colors'
require 'csv'
require 'set'
require 'rod/rest'
require 'syntax'
require 'mapping'
require 'typhoeus'
require 'typhoeus/adapters/faraday'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -d database -f patterns.csv -d heads.csv -o mapping.csv [-p port] [-h host] [-x offset] [-l limit] [-c c:s:n]\n"+
    "Map Wikipedia patterns to Cyc terms."

  on :f=, :patterns, "Category name patterns to map (with matched categories)", required: true
  on :e=, :heads, "Identified pattern heads", required: true
  on :d=, :database, "ROD database with Wikipedia data", required: true
  on :o=, :output, "Output mapping file", required: true
  on :p=, :port, "Cyc port", as: Integer, default: 3601
  on :h=, :host, "Cyc host", default: 'localhost'
  on :x=, :offset, "Pattern offset (skip first N patterns)", as: Integer, default: 0
  on :l=, :limit, "Pattern limit (limit processing to N patterns)", as: Integer
  on :c=, :"category-filters", "Filters for categories: c - collection, s - most specific,\n" +
    "n - noun, r - rewrite of, l - lower case, f - function, c|i - collection or individual, b - black list, d - ill-defined"
  on :a=, :"article-filters", "Filters for articles: as above"
  on :b=, :"black-list", "File with black list of Cyc abstract types"
  on :s=, :services, "File with addresses of ROD-rest services"
  on :v, :verbose, "Display verbose messages (progress is suppresed)"
  on :V, :talkative, "Display detailed messages about potential and matched links (isa/genls)"
  on :r=, :sample, "Sample size of categories matching given pattern", as: Integer, default: 100
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

include Rlp::Wiki

cyc = Cyc::Client.new(port: options[:port], host: options[:host], cache: true)
name_service = Mapping::Service::CycNameService.new(cyc)
black_list_reader = Mapping::BlackListReader.new(options[:"black-list"])
filter_factory = Mapping::Filter::Factory.new(cyc: cyc, black_list: black_list_reader.read)
term_provider = Mapping::TermProvider.
  new(cyc: cyc, name_service: name_service,
      category_filters: filter_factory.filters(options[:"category-filters"]),
      article_filters: filter_factory.filters(options[:"article-filters"]))

services = {}
if options[:services]
  YAML.load_file(options[:services]).each do |id,specification|
    connection = Faraday.new(url: "http://#{specification[:host]}:#{specification[:port]}"){|c| c.adapter(:typhoeus)}
    cache = Rod::Rest::ProxyCache.new(Ref::WeakValueMap.new)
    services[id] = Rod::Rest::Client.new(http_client: connection,proxy_cache: cache)
  end
end
context_provider = Mapping::ContextProvider.new(rlp_services: services)

merger = Mapping::Service::TermMerger.new(cyc: cyc)
mulitiplier = Mapping::CandidateMultiplier.new(merger: merger, black_list: black_list_reader.read, name_service: name_service)
mapping_service = Mapping::Service::PatternMappingService.
  new(term_provider: term_provider, context_provider: context_provider, cyc: cyc, multiplier: mulitiplier,
      verbose: options[:verbose],talkative: options[:talkative], sample_size: options[:sample])


Database.instance.open_database(options[:database])
at_exit do
  Database.instance.close_database
end

heads = {}
CSV.open(options[:heads],"r:utf-8") do |input|
  input.with_progress do |pattern,support,head|
    heads[pattern] = head
  end
end

patterns = []
CSV.open(options[:patterns],"r:utf-8") do |input|
  index = 0
  input.with_progress do |pattern,support,*ids|
    if heads.has_key?(pattern)
      if index >= options[:offset]
        patterns << ids.unshift(heads[pattern]).unshift(support).unshift(pattern)
      end
      index += 1
    end
    break if options[:limit] && index >= options[:limit]
  end
end

CSV.open(options[:output],"w") do |output|
  Progress.start(patterns.size) unless options[:verbose]
  patterns.each do |pattern,support,head,*ids|
    Progress.step(1) unless options[:verbose]
    begin
      # so far we ignore support
      output << mapping_service.candidates_for_pattern(pattern,head,ids.map(&:to_i),support)
    rescue Interrupt
      puts
      break
    rescue Exception => ex
      STDERR.puts "Error for #{pattern}"
      STDERR.puts ex
      STDERR.puts ex.backtrace
    end
  end
end
Progress.stop unless options[:verbose]
