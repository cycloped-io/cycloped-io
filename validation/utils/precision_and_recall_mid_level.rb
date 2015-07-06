#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
$:.unshift "../category-mapping/lib"
require 'progress'
require 'csv'
require 'slop'
require 'set'
require 'colors'
require 'cycr'
require 'mapping'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -m reference.csv -i classification.csv\n" +
             "Counts precision, recall, F1 measure, accuracy, coverage and F1'."

  on :m=, :reference, 'Reference classification', required: true
  on :i=, :classification, 'Automatic (verified) classification', required: true
  on :e=, :errors, 'False negatives and false positives'
  on :g, :genls, 'Count genls relation as true positives'
  on :c, :close, 'Count min-genls inclusion as true positives'
  on :h=, :host, "Cyc host", default: 'localhost'
  on :p=, :port, "Cyc port", as: Integer, default: 3601
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

cyc = Cyc::Client.new(cache: true, host: options[:host], port: options[:port])
name_service = Mapping::Service::CycNameService.new(cyc)

reference = {}
CSV.open(options[:reference], "r:utf-8") do |input|
  input.with_progress do |name, cyc_id, cyc_name|
    next if cyc_name == "Thing"
    reference[name] = [cyc_id, cyc_name]
  end
end

true_positives = 0
false_positives = 0
true_negatives = 0
false_negatives = 0
errors = CSV.open(options[:errors], "w:utf-8") if options[:errors]
CSV.open(options[:classification], "r:utf-8") do |input|
  input.with_progress do |name, *types|
    next unless reference.has_key?(name)
    type_ids = types.each_slice(2).map(&:first)
    reference_id, reference_name = reference[name]
    cyc_term = name_service.find_by_id(reference_id)
    if options[:genls]
      matched = type_ids.map{|id| name_service.find_by_id(id) }.
        select{|type| cyc.with_any_mt{|c| c.genls?(type,cyc_term) } || cyc.with_any_mt{|c| c.genls?(cyc_term,type)} }
    elsif options[:close]
      matched = type_ids.map{|id| name_service.find_by_id(id) }.
        select{|type| cyc.with_any_mt{|c| c.min_genls(type) }.include?(cyc_term.to_ruby) ||
          cyc.with_any_mt{|c| c.min_genls(cyc_term)}.include?(type.to_ruby) } + (type_ids & [reference_id])
    else
      matched = type_ids & [reference_id]
    end
    true_positives += matched.size
    false_positives += type_ids.size - matched.size
    if type_ids.size - matched.size > 0
      output << [name,reference_name,types.each_slice(2).map(&:last)] if errors
    end
  end
end
errors.close if errors

#p true_positives, false_positives, true_negatives, false_negatives

precision = (true_positives) / (true_positives + false_positives).to_f * 100
recall = (true_positives) / reference.size.to_f * 100
f1 = 2 * precision * recall / (precision + recall)
accuracy = (true_positives+ true_negatives).to_f / (true_positives+ false_positives+ true_negatives+ false_negatives)
coverage = (true_positives+ false_positives+ true_negatives+ false_negatives).to_f/reference.size
recall_2 = accuracy * coverage * 100
accuracy *= 100
coverage *= 100
f1_prim = 2 * accuracy * coverage / (accuracy + coverage)

puts '| %-25s | Precision | Recall     | F1          | Accuracy   | Coverage | F1\' | ' % " "
#puts '| %-25s | --------- | ---------- | ----------- | ---------- | -------- | ---- |' % ("-" * 25)
puts '| %-25s | %.1f      | %.1f       | %.1f        | %.1f       | %.1f     | %.1f | ' % [(" " * 25), precision, recall, f1, accuracy, coverage, f1_prim]
