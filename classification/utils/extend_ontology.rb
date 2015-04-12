#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'progress'
require 'csv'
require 'slop'
require 'cycr'
require 'set'
$:.unshift "../category-mapping/lib"
require 'mapping/cyc_term'
require 'mapping/service/cyc_name_service'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f collections.csv -o extension.csv -t terms.csv\n"
    "Extend the ontology with minimal specialization of collections"

  on :f=, :input, "Input file with initial ontology", required: true
  on :o=, :output, "Output file with extended ontology", required: true
  on :t=, :terms, "File with unique collection identifiers", required: true
  on :h=, :host, "Cyc host", default: "localhost"
  on :p=, :port, "Cyc port", as: Integer, default: 3601
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

node = Struct.new(:term,:name,:count)

cyc = Cyc::Client.new(cache: true, host: options[:host], port: options[:port])
name_service = Mapping::Service::CycNameService.new(cyc)

all_nodes = CSV.open(options[:input]).read.map{|t,c| next if t =~ /#/;  node.new(name_service.find_by_term_name(t),t,c.to_i) }.compact
nodes = all_nodes.reject{|n| n.term.nil? }
if all_nodes.size != nodes.size
  puts "Warning, some nodes were skipped"
  (all_nodes - nodes).each{|n| puts "- #{n.name}" }
end

specializations = Set.new
nodes.each.with_progress do |node|
  specializations << node.term
  cyc.with_any_mt{|c| c.max_specs(node.term) }.each do |term|
    specializations << term
  end
end
unique = Set.new
CSV.open(options[:terms],"r:utf-8") do |input|
  input.with_progress do |id,term|
    begin
      unique << name_service.find_by_id(id).to_ruby
    rescue => ex
      puts ex
    end
  end
end
CSV.open(options[:output],"w") do |output|
  specializations.each do |term|
    next unless unique.include?(term)
    output << [term,nil]
  end
end
