#!/usr/bin/env ruby
# encding: utf-8

require 'bundler/setup'
$:.unshift "../category-mapping/lib"
require 'umbel/all'
require 'set'
require 'progress'
require 'csv'
require 'slop'
require 'rdf'
require 'rdf/ntriples'
require 'uri'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -i classification.csv -o classification.nt [-s 2]\n" +
    "Convert CSV classification to NT."

  on :i=, :input, "File with article classification", required: true
  on :o=, :output, "File with article classification in NT format", required: true
  on :s=, :slice, "Slice", default: 2, as: Integer
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

include RDF

RDF::Writer.open(options[:output]) do |output|
CSV.open(options[:input]) do |input|
    graph = RDF::Graph.new
    input.with_progress do |row|
      wiki_name=row.shift
      row.each_slice(options[:slice]) do |triple|
        cyc_id=triple.shift
        output << RDF::Statement(RDF::URI('http://dbpedia.org/resource/%s' % URI.escape(wiki_name.gsub(' ','_'))), RDF.type, RDF::URI('http://sw.opencyc.org/concept/%s' % URI.escape(cyc_id)))
      end
    end
end
end
