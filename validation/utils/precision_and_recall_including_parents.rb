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
require './utils/measures'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -m reference.csv -i classification.csv -s [san]\n" +
             "Counts precision, recall and F1 measure."

  on :m=, :reference, 'Reference classification', required: true
  on :i=, :classification, 'Automatic (verified) classification', required: true
  on :s=, :score, 'Scoring measure: s - simple, a - aprosio, n - aprosio normalized', required: true
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

Thing = name_service.find_by_name('Thing').first

reference = {}
CSV.open(options[:reference], "r:utf-8") do |input|
  input.with_progress do |name, *types|
    types = types.each_slice(2).map{|cyc_id, cyc_name| cyc_id}
    reference[name] = types
  end
end



predicted = {}
CSV.open(options[:classification],"r:utf-8") do |input|
  input.with_progress do |name,*types2|
    reference_types = reference[name]
    if reference_types.nil?
      next
    end
    types = types2.each_slice(2).map{|cyc_id, cyc_name| cyc_id}
    predicted[name] = types
  end
end


measures = {'s' => SimpleScore, 'a' => AprosioScore, 'n' => AprosioScoreNormalized}

scorer = measures[options[:score]].new(name_service)
reference.with_progress do |name, reference_types|
  predicted_types = predicted[name]
  scorer.score(predicted_types, reference_types)
end


precision = scorer.precision
recall = scorer.recall
f1 = scorer.f1

puts '| %-25s | Precision | Recall     | F1          |' % " "
puts '| %-25s | --------- | ---------- | ----------- |' % ("-" * 25)
puts '| %-25s | %.1f      | %.1f       | %.1f        |' % [(" " * 25),precision,recall,f1]

