#!/usr/bin/env ruby

require 'bundler/setup'
require 'slop'
$:.unshift "lib"
require 'resolver/graph_factory'
require 'resolver/renderer'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f edges.csv -o graph.png\n"
    "Create graph of terms."

  on :f=, :input, "Input file with graph edges", required: true
  on :o=, :output, "Output file with graph in form of a graphic file", required: true
  on :t=, :format, "Output file format", default: "png"
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

nodes = Set.new
child_edges = Hash.new{|h,e| h[e] = Set.new }
parent_edges = Hash.new{|h,e| h[e] = Set.new }

relations = File.readlines(options[:input]).map(&:chomp).each do |line|
  child,parent = line.split(/\s*<-\s*/)
  nodes << child << parent
  child_edges[child] << parent
  parent_edges[parent] << child
end

factory = Resolver::GraphFactory.new do |node1,node2|
  if child_edges[node1].include?(node2)
    -1
  elsif parent_edges[node2].include?(node1)
    1
  else
    0
  end
end

graph = factory.create(nodes)

renderer = Resolver::Renderer.new("cyc",graph.roots)
renderer.render(options[:output],options[:format])
