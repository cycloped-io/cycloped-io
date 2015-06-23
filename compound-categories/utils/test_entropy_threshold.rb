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
  on :v=, :mode, 'Entropy (e) or probability (p) of the best', required: true
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
    type = types.each_slice(3).first #.map { |cyc_id, cyc_name, probability| cyc_id }.first
    cyc_id, cyc_name, probability = type

    if options[:mode]=="e"
      value=entropy.to_f
      elsif options[:mode]=="p"
        value=probability.to_f
    end
    classification << [name, value, cyc_id]
  end
end

puts "Coverage: %s" % classification.size

scores = {}

sorted_classification = classification.sort_by { |name, value, type| value }
sorted_classification.reverse! if options[:mode]=="p"


sorted_classification.with_progress do |name, entropy, type|
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


puts '| %-25s | Value     | Precision | Recall     | F1          |' % " "
puts '| %-25s | --------- | --------- | ---------- | ----------- |' % ("-" * 25)

scores.sort_by{|value,tpfp| value}.each do |entropy,tpfp|
  true_positives,false_positives=tpfp
  precision = (true_positives) / (true_positives + false_positives).to_f * 100
  recall = (true_positives) / reference.size.to_f * 100
  f1 = 2 * precision * recall / (precision + recall)
  puts '| %-25s | %.3f      | %.1f      | %.1f       | %.1f        |' % [(" " * 25), entropy, precision, recall, f1]
end



