#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'progress'
require 'csv'
require 'slop'
require 'cycr'

$:.unshift '../category-mapping/lib'
require 'mapping/cyc_term'
require 'mapping/service/cyc_name_service'
require 'mapping/bidirectional_map'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -b sd_dbpedia_class_cyc_mapping.csv -i dbpedia_to_cyc.csv -c pair_conflicts.csv \n" +
             "Checks consistency of collections of articles."

  on :b=, :dbpedia_instances, "File with DBpedia instances; columns: 1. instance name, 2-N. DBpedia class names", required: true
  on :i=, :dbpedia_to_cyc, "File with DBpedia classes to Cyc mapping; columns: 1. DBpedia name, 2. Cyc ID", required: true
  on :c=, :pair_conflicts, "File with pair conflicts", required: true
  on :h=, :host, 'Cyc host (localhost)', default: 'localhost'
  on :p=, :port, 'Cyc port (3601)', as: Integer, default: 3601
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

cyc = Cyc::Client.new(host: options[:host], port: options[:port], cache: true)
name_service = Mapping::Service::CycNameService.new(cyc)

def disjoint?(terms, cyc)
  result = []
  terms.each do |t1|
    terms.each do |t2|
      next if t1.to_s>=t2.to_s
      if cyc.collections_disjoint?(t1, t2)
        result.push([t1, t2])
      end
    end
  end
  return result
end

def not_disjoint_with_typeGenls?(term1, term2, cyc, name_service)
  result = cyc.cyc_query(-> { '`(#$typeGenls '+term1.to_cyc(true)+' ?s)' }, :UniversalVocabularyMt)
  return false if result==nil

  typeGenls = result.map { |e| name_service.convert_ruby_term(name_service.extract_term_name(e.first)) }
  return !disjoint?(typeGenls+[term2], cyc)
end

dbpedia_to_cyc = Hash.new
CSV.open(options[:dbpedia_to_cyc]) do |file|
  file.each do |dbpepdia, cyc|
    dbpedia_to_cyc[dbpepdia] = cyc
  end
end


disjoint_pairs = Hash.new(0)

stats = Hash.new(0)

CSV.open(options[:dbpedia_instances]) do |dbpedia_instances|
  dbpedia_instances.with_progress do |dbpedia, *cycs|
    stats['concepts'] += 1
    terms = cycs.map { |c| dbpedia_to_cyc[c] }.reject { |cycid| cycid==nil }.map { |cycid| name_service.find_by_id(cycid) }
    disjoint = disjoint?(terms, cyc)
    if not disjoint.empty?
      stats['conflicts'] += 1
      p dbpedia, cycs, terms
      disjoint.each do |term1,term2|
        disjoint_pairs[[term1, term2]]+=1
        puts term1.to_s+ ' - '+term2.to_s
      end
      puts
    end
  end
end

CSV.open(options[:pair_conflicts], 'w') do |pair_conflicts|
  disjoint_pairs.sort_by { |k, v| v }.reverse.each do |terms, count|
    term1, term2 = terms

    isa = cyc.isa?(term1, term2) || cyc.isa?(term2, term1)
    typeGenls = not_disjoint_with_typeGenls?(term1, term2, cyc, name_service) || not_disjoint_with_typeGenls?(term2, term1, cyc, name_service)
    status = 'DISJOINT'+((isa) ? ', ISA' : '')+((typeGenls) ? ', NOT DISJOINT typeGenls' : '')

    pair_conflicts << [term1.to_s, term2.to_s, count, status]
  end
end

puts stats