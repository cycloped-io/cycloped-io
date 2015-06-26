#!/usr/bin/env ruby
# encding: utf-8

require 'bundler/setup'
$:.unshift "../category-mapping/lib"
require 'set'
require 'progress'
require 'csv'
require 'slop'
require 'mapping'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -f classification.csv -c mid_level_classification.csv -o new_classification.csv\n" +
    "Assign Cyc mid-level concepts using classification."

  on :f=, :input, "File with entities classification", required: true
  on :o=, :output, "File with classification to high-level concepts", required: true
  on :c=, :types, "Cyc high-level concepts (data/high_level/classification_3i.csv)", required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end


midlevel = {}
CSV.open(options[:types]) do |input|
  input.with_progress do |cyc_id, cyc_name,_,midlevel_cyc_id, midlevel_cyc_name|
    midlevel[cyc_id]=[midlevel_cyc_id, midlevel_cyc_name]
    midlevel[midlevel_cyc_id]=[midlevel_cyc_id, midlevel_cyc_name]
  end
end



CSV.open(options[:input]) do |input|
  CSV.open(options[:output],"w") do |output|
    input.with_progress do |name, *types|
      midlevel_types = types.each_slice(3).map{|cyc_id, cyc_name, probability| midlevel[cyc_id]}.uniq

      output << [name]+midlevel_types.flatten
    end
  end
end
