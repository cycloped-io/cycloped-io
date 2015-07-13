#!/usr/bin/env ruby
# encoding: utf-8
require 'experiment_arguments_log/auto'

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
  banner "#{$PROGRAM_NAME} -m reference.csv -i classification.csv -s [s,a,n,w,ma,cm]\n" +
             "Counts precision, recall and F1 measure."

  on :m=, :reference, 'Reference classification', required: true
  on :i=, :classification, 'Automatic (verified) classification', required: true
  on :s=, :score, 'Scoring measure: s - simple (micro), a - aprosio, n - aprosio normalized, ma - macro, w - weighted, cm - confusion matrix', required: true
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
    reference[name] = types.each_slice(2).map{|cyc_id, cyc_name| cyc_id}
  end
end



predicted = {}
CSV.open(options[:classification],"r:utf-8") do |input|
  input.with_progress do |name,*types|
    reference_types = reference[name]
    if reference_types.nil?
      next
    end
    predicted[name] = types.each_slice(2).map{|cyc_id, cyc_name| cyc_id}
  end
end


measures = {'s' => SimpleScore, 'a' => AprosioScore, 'n' => AprosioScoreNormalized, 'w' => WeightedAveraged, 'ma' => MacroAveraged, 'cm' => ConfusionMatrix}

scorer = measures[options[:score]].new(name_service)
reference.with_progress do |name, reference_types|
  predicted_types = predicted[name]
  scorer.score(predicted_types, reference_types, name=name)
end

begin
  scorer.print
  puts 'INVERTED'
  scorer.print(inverted=true)
  exit
rescue NoMethodError
end

accuracy = scorer.accuracy
precision = scorer.precision
recall = scorer.recall
f1 = scorer.f1

puts '| %-25s | Precision | Recall     | F1          | Accuracy |' % " "
puts '| %-25s | --------- | ---------- | ----------- | -------- |' % ("-" * 25)
puts '| %-25s | %.1f      | %.1f       | %.1f        | %.1f     |' % [(" " * 25),precision,recall,f1, accuracy]

