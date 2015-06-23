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
             "Counts precision, recall and F1 measure in relation to entropy threshold."

  on :m=, :reference, 'Reference classification', required: true
  on :i=, :classification, 'Automatic (verified) classification with entropy (float) in second column', required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

mismatch_file = CSV.open(options[:mismatch], "w") if options[:mismatch]

reference = {}
CSV.open(options[:reference], "r:utf-8") do |input|
  input.with_progress do |name, *types|
    types = types.each_slice(2).map { |cyc_id, cyc_name| cyc_id }
    reference[name] = types
  end
end

true_positives = 0
false_positives = 0

mismatch_file = CSV.open(options[:mismatch], "w") if options[:mismatch]


classification = []
CSV.open(options[:classification], "r:utf-8") do |input|
  input.with_progress do |name, entropy, *types|
    next if reference[name].nil?
    type = types.each_slice(3).map { |cyc_id, cyc_name, probability| cyc_id }.first
    classification << [name, entropy.to_f, type]
  end
end

puts "Coverage: %s" % classification.size

scores = {}
classification.sort_by { |name, entropy, type| entropy }.with_progress do |name, entropy, type|
  reference_types = reference[name]
  next if reference_types.nil?
  reference_type = reference_types.first
  if reference_type == type
    true_positives+=1
  else
    false_positives+=1
  end
  scores[entropy]=[true_positives,false_positives]
end



mismatch_file.close if mismatch_file


puts '| %-25s | Entropy   | Precision | Recall     | F1          |' % " "
puts '| %-25s | --------- | --------- | ---------- | ----------- |' % ("-" * 25)

scores.each do |entropy,v|
  true_positives,false_positives=v
  precision = (true_positives) / (true_positives + false_positives).to_f * 100
  recall = (true_positives) / reference.size.to_f * 100
  f1 = 2 * precision * recall / (precision + recall)
  puts '| %-25s | %.3f      | %.1f      | %.1f       | %.1f        |' % [(" " * 25), entropy, precision, recall, f1]
end



