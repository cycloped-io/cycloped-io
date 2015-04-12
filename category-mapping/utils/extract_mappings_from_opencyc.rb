#!/usr/bin/env ruby

require 'uri'
require 'progress'
require 'rdf'
require 'rdf/raptor'
require 'slop'
require 'cycr'
require 'csv'
require 'colors'
$:.unshift "lib"
require 'mapping/cyc_term'
require 'mapping/service/cyc_name_service'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f opencyc-latest.owl -m cyc_wiki_umbel.csv\n" +
    "Extract mappings to Umbel, DBpedia or wiki from opencyc-latest.owl"

  on :f=, :input, "File full OpenCyc content", required: true # http://sw.opencyc.org/downloads/opencyc_owl_downloads_v4/opencyc-latest.owl.gz
  on :m=, :mapping, "Mapping between Cyc concepts and Umbel concepts, DBpedia links and Wiki links (CSV)", required: true
end

begin
  options.parse
rescue
  puts options
  exit
end

CSV.open(options[:mapping],"w") do |output|
  RDF::Reader.open(options[:input], :format => :rdfxml) do |reader|
    term=nil
    umbel=[]
    dbpedia=[]
    wiki=[]
    cycterm=[]
    Progress.start(2956251)
    reader.each_statement do |statement|
      Progress.step
      if statement.object.to_s=='http://www.w3.org/2002/07/owl#Class' and statement.predicate.to_s == 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type'
        if not umbel.empty? or not dbpedia.empty? or not wiki.empty? or not cycterm.empty?
          output << [term,umbel.first,dbpedia.first,wiki.first,cycterm.first]
          #break
        end
        m=/concept\/(.*)/.match(statement.subject.to_s)
        term = m[1]
        umbel=[]
        dbpedia=[]
        wiki=[]
        cycterm=[]
      elsif statement.predicate=='http://www.w3.org/2002/07/owl#sameAs'
        resource = statement.object.to_s
        if resource.start_with? 'http://umbel.org/umbel/sc/'
          umbel.push resource[26..-1].chomp '_'
        elsif resource.start_with? 'http://dbpedia.org/resource/'
          dbpedia.push URI.unescape(resource[28..-1])
        end
      elsif statement.predicate == 'http://sw.cyc.com/CycAnnotations_v1#label'
        cycterm.push URI.unescape(statement.object.to_s)
      elsif statement.predicate == 'http://sw.opencyc.org/concept/Mx4rNv0nbm4TTjOp7yhmnzOyqg' # Wikipedia
        wiki.push URI.unescape(statement.object.to_s[29..-1])
      elsif statement.predicate == 'http://sw.opencyc.org/2008/06/10/concept/wikipediaArticleURL' # Wikipedia in old OWL
        wiki.push URI.unescape(statement.object.to_s[29..-1])
      end

    end

    if not umbel.empty? or not dbpedia.empty? or not wiki.empty?
      output << [term,umbel.first,dbpedia.first,wiki.first,cycterm.first]
    end

    Progress.stop
  end
end
