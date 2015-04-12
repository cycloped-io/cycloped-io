#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'progress'
require 'csv'
require 'slop'
require 'cycr'
$:.unshift "../category-mapping/lib"
require 'mapping/cyc_term'
require 'mapping/service/cyc_name_service'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f terms.csv -o partition.csv\n"
    "Convert list of Cyc term names to a graph"

  on :f=, :input, "Input file with terms", required: true
  on :o=, :output, "Output file with partition", required: true
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
File.open(options[:output],"w") do |output|
  nodes.each.with_progress do |child_node|
    nodes.each do |parent_node|
      next if child_node == parent_node
      if cyc.with_any_mt{|c| c.genls?(child_node.term,parent_node.term) }
        output.puts "#{parent_node.term.to_ruby}-#{parent_node.count} <- #{child_node.term.to_ruby}-#{child_node.count}"
      end
    end
  end
end
