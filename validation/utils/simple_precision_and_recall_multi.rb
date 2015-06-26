#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'progress'
require 'csv'
require 'slop'
require 'set'
require 'colors'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -m reference.csv -i classification.csv\n" +
             "Counts precision, recall and F1 measure."

  on :m=, :reference, 'Reference classification', required: true
  on :i=, :classification, 'Automatic (verified) classification', required: true
  on :x=, :mismatch, 'Algorithm errors (CSV)'
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

mismatch_file = CSV.open(options[:mismatch],"w") if options[:mismatch]

reference = {}
reference2 = {}
CSV.open(options[:reference], "r:utf-8") do |input|
  input.with_progress do |name, *types|
    reference2[name] = types
    types = types.each_slice(2).map{|cyc_id, cyc_name| cyc_id}
    reference[name] = types
  end
end

true_positives = 0
false_positives = 0
false_negatives = 0
mismatch_file = CSV.open(options[:mismatch],"w") if options[:mismatch]


visited = []
CSV.open(options[:classification],"r:utf-8") do |input|
  input.with_progress do |name,*types2|
    reference_types = reference[name]
    if reference_types.nil?
      next
    end
    types = types2.each_slice(2).map{|cyc_id, cyc_name| cyc_id}
    true_positives+=(types&reference_types).size
    false_positives+=(types-reference_types).size
    false_negatives+=(reference_types-types).size

    if (types-reference_types).size>0 || (reference_types-types).size>0
      mismatch_file << [name]+types2+['---']+reference2[name] if mismatch_file
    end
  end
end

mismatch_file.close if mismatch_file

precision = (true_positives) / (true_positives + false_positives).to_f * 100
recall = (true_positives) / reference.size.to_f * 100
f1 = 2 * precision * recall / (precision + recall)

puts '| %-25s | Precision | Recall     | F1          |' % " "
puts '| %-25s | --------- | ---------- | ----------- |' % ("-" * 25)
puts '| %-25s | %.1f      | %.1f       | %.1f        |' % [(" " * 25),precision,recall,f1]

