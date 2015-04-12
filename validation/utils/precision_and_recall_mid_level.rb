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
  on :e=, :errors, 'False negatives and false positives', required: true
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
  input.with_progress do |decision, name, cyc_id, cyc_name|
    reference[name] = [decision, cyc_id, cyc_name]
  end
end

true_positives = 0
false_positives = 0
true_negatives = 0
false_negatives = 0
CSV.open(options[:errors], "w:utf-8") do |output|
  CSV.open(options[:classification], "r:utf-8") do |input|
    input.with_progress do |name, *types|
      next unless reference.has_key?(name)
      decision, cyc_id, cyc_name = reference[name]
      matched = types.include?(cyc_id)
      if !matched
        cyc_term = name_service.find_by_id(cyc_id)
        matched = types.each_slice(2).to_a.map{|k,v| k}.any?{|type| cyc.with_any_mt{|c| c.genls?(name_service.find_by_id(type),cyc_term) }}
      end
      if decision=='v'
        if matched
          true_positives+=1
        else
          false_negatives+=1
          output << [name]+reference[name]+types
        end
      else # invalid
        if matched
          false_positives+=1
          output << [name]+reference[name]+types
        else
          true_negatives+=1
        end
      end
    end
  end
end

#p true_positives, false_positives, true_negatives, false_negatives

precision = (true_positives) / (true_positives + false_positives).to_f * 100
recall = (true_positives) / (true_positives + false_negatives).to_f * 100
f1 = 2 * precision * recall / (precision + recall)
accuracy = (true_positives+ true_negatives).to_f / (true_positives+ false_positives+ true_negatives+ false_negatives) * 100
coverage = (true_positives+ false_positives+ true_negatives+ false_negatives).to_f/reference.size*100
f1_prim = 2 * accuracy * coverage / (accuracy + coverage)

puts '| %-25s | Precision | Recall     | F1          | Accuracy   | Coverage | F1\' |' % " "
puts '| %-25s | --------- | ---------- | ----------- | ---------- | -------- | ---- |' % ("-" * 25)
puts '| %-25s | %.1f      | %.1f       | %.1f        | %.1f       | %.1f     | %.1f |' % [(" " * 25), precision, recall, f1, accuracy, coverage, f1_prim]