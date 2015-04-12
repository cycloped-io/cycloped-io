#!/usr/bin/env ruby
# encoding: utf-8

require 'progress'
require 'yaml'
require 'rdf'
require 'rdf/turtle'
require 'rdf/n3'
require 'csv'
require 'slop'
require 'set'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -i dbpedia_instances.ttl -o output.csv \n" +
             "Transform DBpedia classification file to CSV format."

  on :i=, :classification, "File with DBpedia classification", required: true
  on :o=, :output, 'File with DBpedia instances in CSV format', required: true
  on :h=, :ontology, 'File with DBpedia ontology (YAML)', required: true
  on :f=, :format, 'Format of file with classification (default: ttl)', default: :ttl, as: Symbol
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

types = Hash.new{|h,e| h[e] = [] }
hierarchy = YAML.load_file(options[:ontology])
ontology = {}
hierarchy.each do |klass,superclasses|
  ontology[klass[klass.rindex("/")+1..-1]] = superclasses.map{|s| s[s.rindex("/")+1..-1] }
end
include URI::Escape

Progress.start(`wc -l #{options[:classification]}`.to_i)
RDF::Reader.open(options[:classification], :format => options[:format]) do |reader|
  begin
    reader.each_statement do |statement|
      Progress.step
      next if statement.object.to_s !~ /dbpedia\.org/

      type = statement.object.to_s
      type = type[type.rindex("/")+1..-1]

      subject = statement.subject.to_s
      subject = unescape(subject[subject.rindex("/")+1..-1].gsub("_"," "))
      types[subject] << type
    end
  rescue Interrupt
    puts
  end
end
Progress.stop

CSV.open(options[:output], 'w') do |result|
  types.each do |instance, classes|
    to_remove = Set.new
    classes.each do |klass|
      (ontology[klass] || []).each{|superklass| to_remove << superklass }
    end
    classes -= to_remove.to_a
    result << [instance, *classes]
  end
end
