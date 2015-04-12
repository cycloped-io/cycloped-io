#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
$:.unshift "../category-mapping/lib"
require 'umbel/all'
require 'slop'
require 'csv'
require 'progress'
require 'set'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -u umbels.csv\n" +
             "Super types statistics"

  on :u=, :umbels, "CSV with UMBEL concepts in first column", required: true
end

begin
  options.parse
rescue Exception
  puts options
  exit
end


umbel_concepts = Set.new

CSV.open(options[:umbels]) do |csv|
  csv.each do |umbel|
    umbel_name = umbel.first
    umbel_concepts.add umbel_name
  end
end

search_service = Umbel::Serializer.auto(Umbel::SearchService,'../category-mapping/data/umbel_concepts.csv',
                                        '../category-mapping/data/umbel_to_cyc_mapping.csv')

stats = Hash.new { |h, k| h[k] = [0, 0] }

search_service.concept_map.each do |umbel_name, concept|
  concept.super_types.each do |super_type|
    stats[super_type.name][0]+=1
    stats[super_type.name][1]+=1 if !umbel_concepts.include? umbel_name
  end
end

puts 'Statistics of used UMBEL concepts:'
stats.sort_by { |k, v| v[1].to_f/v[0] }.reverse.each do |super_type, v|
  puts '%s %.2f%% out of %d' % [super_type, 100.0*v[1]/v[0], v[0]]
end
