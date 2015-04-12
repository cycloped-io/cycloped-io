#!/usr/bin/env ruby

#require 'bundler/setup'
require 'rdf'
require 'rdf/rdfxml'
require 'addressable/uri'
require 'slop'
require 'csv'
require 'yaml'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -f ontology.owl -o ontology_tree.yml\n" +
    "Export ontology tree to YAML format"

  on :f=, :ontology, "Ontology (OWL)", required: true
  on :o=, :output, "Output file with ontology tree (yaml)", required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

class Node < Struct.new(:name,:parent,:children)
end

def get_node(name,nodes)
  return nodes[name] if nodes[name]
  node = Node.new(name,nil,[])
  nodes[name] = node
end

graph = RDF::Graph.load(options[:ontology])
query = RDF::Query.new({:klass => {RDF.type => RDF::OWL.Class, RDF::RDFS.subClassOf => :superklass}})
index = 0
hierarchy = Hash.new{|h,e| h[e] = [] }
CSV.open(options[:output],"w") do |output|
  output << ["#class","superclass"]
  query.execute(graph) do |solution|
    if solution.superklass.to_s =~ /dbpedia/
      hierarchy[solution.klass.to_s] << solution.superklass.to_s
    end
  end
end
nodes = {}
hierarchy.each do |klass,superklasses|
  if superklasses.size == 1
    parent_node = get_node(superklasses.first,nodes)
    child_node = get_node(klass,nodes)
    parent_node.children << child_node
    child_node.parent = parent_node
  else
    puts "Multiple parents for #{klass}"
  end
end
nodes.each do |node|
end
File.open(options[:output],"w"){|o| o.puts YAML.dump(hierarchy) }
