#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'slop'
require 'progress'
require 'rlp/wiki'
require 'sparql/client'
require 'colors'
require 'csv'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -d database -f patterns.csv -o mapped.csv -p port -h host [-x offset]\n"+
    "Map simple patterns to DBpedia predicates."

  on :d=, :database, "ROD database with Wikipedia data", required: true
  on :f=, :input, "File with simple patterns (CSV)", required: true
  on :o=, :output, "Output mapping file", required: true
  on :p=, :port, "DBpedia port", as: Integer, required: true
  on :h=, :host, "DBpeida host", required: true
  on :x=, :offset, "Pattern offset", as: Integer, default: 0
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

include Rlp::Wiki
Database.instance.open_database(options[:database])

QUERY = "select * from <http://dbpedia.org> where {<http://dbpedia.org/resource/%s> ?predicate <http://dbpedia.org/resource/%s>}"
client = SPARQL::Client.new("http://#{options[:host]}:#{options[:port]}/sparql")
index = -1
Progress.start(`wc -l #{options[:input]}`.to_i)
CSV.open(options[:output],"a") do |output|
  unless options[:offset] == 0
    output << %w{#pattern relation category_id category_name subject_id subject_name object_id object_name}
  end
  CSV.open(options[:input]) do |input|
    input.each do |row|
      begin
        Progress.step
        index += 1
        next if index < options[:offset]
        #break if index > 1
        pattern,count,*pairs = row
        # we skip rare patterns
        break if pairs.size / 2 < 10
        slices = pairs[0...100].each_slice(2).to_a
        concept_index = 0
        confirmation_count = 0
        while(!slices.empty?) do
          concept_index += 1
          slices_to_remove = []
          slices.each.with_index do |(category_id,concept_id),index|
            begin
              category = Category.find_by_wiki_id(category_id.to_i)
              concept = Concept.find_by_wiki_id(concept_id.to_i)
              if category.nil? || concept.nil? || category.concepts.size <= concept_index
                slices_to_remove << index
                next
              end
              child_concept = category.concepts[concept_index]
              next if child_concept.nil?
              child_name = CGI.escape(child_concept.name.gsub(" ","_"))
              concept_name = CGI.escape(concept.name.gsub(" ","_"))
              query = QUERY % [child_name,concept_name]
              results = client.query(query)
              results.each do |result|
                output << [pattern,result.predicate.to_s,category_id,category.name,child_concept.wiki_id,child_concept.name,concept_id,concept.name]
                confirmation_count += 1
              end
            rescue Interrupt
              raise
            rescue Exception => ex
              puts ex
              puts ex.backtrace[0..3]
            end
          end
          break if confirmation_count > 300
          slices.delete_if.with_index{|e,i| slices_to_remove.include?(i) }
        end
      rescue Interrupt
        puts
        break
      rescue Exception => ex
        puts ex
        puts ex.backtrace[0..3]
      end
    end
  end
end
Progress.stop

Database.instance.close_database
