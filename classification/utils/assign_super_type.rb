#!/usr/bin/env ruby
# encding: utf-8

require 'bundler/setup'
$:.unshift "../category-mapping/lib"
require 'umbel/all'
require 'set'
require 'progress'
require 'csv'
require 'slop'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -f classification.csv -m cyc_umbel.csv -t umbel_hierarchy.dat -o types.csv\n" +
    "Assign UMBEL super types to articles based on classification and Cyc-UMBEL mapping."

  on :f=, :input, "File with article classification", required: true
  on :o=, :output, "File with classification to UMBEL super types", required: true
  on :m=, :mapping, "Cyc-to-UMBEL mapping", required: true
  on :t=, :types, "UMBEL reference-concepts to super types classification", required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

search_service = Umbel::SearchService.new(options[:types],options[:mapping])
CSV.open(options[:input]) do |input|
  CSV.open(options[:output],"w") do |output|
    input.with_progress do |row|
      article_name, cyc_id, _ = row
      output_row = [article_name]
      umbel_concept = search_service.cyc_map[cyc_id]
      next if umbel_concept.nil?
      umbel_concept.super_types.each do |super_type|
        output_row << super_type
      end
      output << output_row if output_row.size > 1
    end
  end
end
