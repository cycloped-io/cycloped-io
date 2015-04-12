#!/usr/bin/env ruby

require 'rdf'
require 'rdf/n3'
require 'slop'
require 'cycr'
require 'csv'
require 'colors'
$:.unshift "lib"
require 'mapping/cyc_term'
require 'mapping/service/cyc_name_service'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f wikipediaCategories.n3 -m manual_umbel_wiki_cyc.csv -e missing.csv [-p port] [-h host]\n" +
    "Convert mappings from Wikipedia categories to Umbel concepts to Cyc concepts."

  on :f=, :input, "File with Umbel concepts and DBpedia links (CSV)", required: true
  on :m=, :mapping, "Output mapping between Umbel concepts, DBpedia links and Cyc concepts (CSV)", required: true
  on :e=, :missing, "File with mappings of Umbel concepts that were not found in Cyc or were ambigous", required: true
  on :p=, :port, "Cyc port", as: Integer
  on :h=, :host, "Cyc host"
end

begin
  options.parse
rescue
  puts options
  exit
end

def term_to_output(cyc_term)
  [cyc_term.id,cyc_term.to_ruby.to_s]
end

cyc = Cyc::Client.new(port: options[:port] || 3601, host: options[:host] || "localhost")
name_service = Mapping::Service::CycNameService.new(cyc)

CSV.open(options[:missing],"w") do |missing|
  CSV.open(options[:mapping],"w") do |output|
    RDF::N3::Reader.open(options[:input]) do |reader|
      reader.each_statement do |statement|

        dbpedia=statement.subject.to_s[37..-1]
        umbel=statement.object.to_s[26..-1]


        name = umbel.dup
        name.gsub!('_','-')
        cyc_term = name_service.find_by_term_name(name)
        unless cyc_term.nil?
          output << [dbpedia,umbel,*term_to_output(cyc_term)]
          next
        end

        name.gsub!('-',' ')
        begin
          cyc_term = name_service.find_by_label(name)
          unless cyc_term.nil?
            output << [dbpedia,umbel,*term_to_output(cyc_term)]
            next
          end
        rescue Mapping::AmbiguousResult => ex
          results = ex.results.map!{|t| term_to_output(t) }
          missing << [dbpedia,umbel,*results]
          next
        end

        cyc_terms = name_service.find_by_name(name)
        if cyc_terms.size == 1
          output << [dbpedia,umbel,*term_to_output(cyc_terms.first)]
          next
        elsif cyc_terms.size > 1
          missing << [dbpedia,umbel,*cyc_terms.map{|t| term_to_output(t)}.flatten(1)]
          next
        end

        missing << [dbpedia,umbel]
      end
    end
  end
end
