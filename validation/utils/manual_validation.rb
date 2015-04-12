#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'slop'
require 'csv'
require 'progress'
require 'colors'
require 'cycr'
require 'set'
require 'open-uri'
require 'nokogiri'
$:.unshift "lib"

include URI::Escape

def wiki_uri(article_name,namespace)
  "http://#{namespace}.wikipedia.org/wiki/#{encode(article_name.tr(" ","_"))}"
end

def print_abstract(article_name,namespace)
  uri = wiki_uri(article_name,namespace)
  puts uri
  file = open(uri)
  doc =  Nokogiri.HTML(file.read)
  nodes = doc.css('#mw-content-text > p')
  start_found = false
  nodes.each do |node|
    puts node.inner_text
    puts "Continue abstract printing (y/n)?".hl(:yellow)
    answer = STDIN.gets
    case answer
    when /^n/i
      break
    end
  end
end

options = Slop.new do
  banner "#{$PROGRAM_NAME} -c classification.csv -o validation.csv\n" +
    "Manually validate Wikipedia classification"

  on :i=, :input, "Input file with classification"
  on :v=, :validation, "Input file with validation"
  on :o=, :output, "Output file with validation", required: true
  on :c=, :count, "Number of concepts to validate", default: 100, as: Integer
  on :p=, :port, "Cyc port", default: 3601, as: Integer
  on :h=, :host, "Cyc host", default: "localhost"
  on :w=, :wikipedia, "Wikipedia language version", default: "en"
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

if options[:input]
  if options[:validation]
    puts "Only input or validation might be specified"
    puts options
    exit
  end
else
  unless options[:validation]
    puts "Either input or validation has to be specified"
    puts options
    exit
  end
end


cyc = Cyc::Client.new(port: options[:port], host: options[:host], cache: true)

selected = []
if options[:validation]
  CSV.open(options[:validation],"r:utf-8") do |input|
    input.each do |tuple|
      selected << tuple
    end
  end
else
  total_count = `wc -l #{options[:input]}`.to_i
  selected_ids = Set.new(options[:count].times.map{ rand(total_count) } )
  CSV.open(options[:input],"r:utf-8") do |input|
    index = -1
    input.each do |tuple|
      index += 1
      next unless selected_ids.include?(index)
      concept = tuple.shift
      terms = {}
      tuple.each_slice(3) do |id,name,probability|
        terms[id] = name
      end
      id = terms.keys.sample
      name = terms[id]
      selected << [concept,id,name]
      break if selected_ids.size == selected.size
    end
  end
end

stats = Hash.new(0)
CSV.open(options[:output],"w") do |output|
  concept_index = 0
  selected.each do |tuple|
    concept,id,name = tuple.last(3)
    stop_evaluation = false
    puts "#{concept_index+1}/#{selected.size}. " + concept.hl(:green)
    puts wiki_uri(concept,"en")
    puts name.hl(:blue)
    loop do
      puts "Valid (v) / Invalid (i) / Unsure (u) / Wikipedia abstract (w) / Cyc comment (c) / Cyc parents (p) / Stats (s) / Stop validation (x) "
      answer = STDIN.gets.chomp
      case answer
      when /^v/i
        output << tuple.unshift("y")
        stats["y"] += 1
        break
      when /^i/i
        output << tuple.unshift("n")
        stats["n"] += 1
        break
      when /^u/i
        output <<  tuple.unshift("u")
        stats["u"] += 1
        break
      when /^w/i
        print_abstract(concept,options[:wikipedia])
      when /^c/i
        puts "http://sw.opencyc.org/concept/#{id}"
        puts cyc.comment{|cyc| cyc.find_cycl_object_by_compact_hl_external_id_string(id) }
      when /^p/i
        puts (cyc.min_genls{|c| c.find_cycl_object_by_compact_hl_external_id_string(id) } || []).join(", ").hl(:purple)
      when /^s/i
        puts "Valid/invalid/total #{stats["y"]}/#{stats["n"]}/#{stats["y"]+stats["n"]}"
      when /^x/i
        stop_evaluation = true
        break
      end
    end
    concept_index += 1
    break if stop_evaluation
    puts
  end
end
