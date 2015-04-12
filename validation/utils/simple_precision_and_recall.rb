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
             "Counts precision, recall and F1 measure.\n"+
             "Assumes only one valid decision. Any result consistent with the reference is considered valid."

  on :m=, :reference, 'Reference classification', required: true
  on :i=, :classification, 'Automatic (verified) classification', required: true
  on :x=, :mismatch, 'Algorithm errors (CSV)'
  on :t=, :trace, 'Trace of decitions (for computing statistical significance) (CSV)'
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

reference = {}
CSV.open(options[:reference], "r:utf-8") do |input|
  input.with_progress do |name, type|
    reference[name] = type
  end
end

true_positives = 0
false_positives = 0
mismatch_file = CSV.open(options[:mismatch],"w") if options[:mismatch]
trace_file = CSV.open(options[:trace],"w") if options[:trace]

visited = []
CSV.open(options[:classification],"r:utf-8") do |input|
  input.with_progress do |name,*types|
    next unless reference.has_key?(name)
    visited << name
    reference_type = reference[name]
    if types.include?(reference_type)
      true_positives += 1
      trace_file << [name,1] if trace_file
    else
      false_positives += 1
      mismatch_file << [name,reference_type,*types] if mismatch_file
      trace_file << [name,0] if trace_file
    end
  end
end

if trace_file
  (reference.keys - visited).each do |name|
    trace_file << [name,0]
  end
end

mismatch_file.close if mismatch_file
trace_file.close if trace_file

precision = (true_positives) / (true_positives + false_positives).to_f * 100
recall = (true_positives) / reference.size.to_f * 100
f1 = 2 * precision * recall / (precision + recall)

puts '| %-25s | Precision | Recall     | F1          |' % " "
puts '| %-25s | --------- | ---------- | ----------- |' % ("-" * 25)
puts '| %-25s | %.1f      | %.1f       | %.1f        |' % [(" " * 25),precision,recall,f1]
