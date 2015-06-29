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

Thing = name_service.find_by_name('Thing')

class Score
  def initialize(name_service=nil)
    @true_positives = 0
    @false_positives = 0
    @false_negatives = 0
    @name_service=name_service
  end

  def score(predicted, reference)
    predicted,reference = preprocess(predicted, reference)
    true_positives,false_positives,false_negatives=example_score(predicted, reference)

    @true_positives += true_positives
    @false_positives += false_positives
    @false_negatives += false_negatives

    return true_positives,false_positives,false_negatives
  end

  def example_score(predicted, reference)
    true_positives=(predicted&reference).size
    false_positives=(predicted-reference).size
    false_negatives=(reference-predicted).size

    return true_positives,false_positives,false_negatives
  end

  def preprocess(predicted, reference)

  end
end

class SimpleScore < Score
  def preprocess(predicted, reference)
    if predicted.nil?
      predicted = []
    end

    return predicted, reference
  end
end

class AprosioScore < Score
  def preprocess(predicted, reference)
    if predicted.nil?
      predicted_genls = [Thing]
    else
      predicted_genls = predicted.map{|cyc_id|  @name_service.cyc.all_genls(@name_service.find_by_id(cyc_id))}.flatten.uniq
    end
    reference_genls =reference.map{|cyc_id| @name_service.cyc.all_genls(@name_service.find_by_id(cyc_id))}.flatten.uniq

    return predicted_genls,reference_genls
  end
end

class AprosioScoreNormalized < AprosioScore
  alias aprosio_example_score example_score
  def example_score(predicted, reference)
    tp,fp,fn=aprosio_example_score(predicted, reference)
    sum = (tp+fp+fn).to_f

    return tp/sum, fp/sum, fn/sum
  end
end





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

  tp,fp,fn=scorer.score(predicted_types, reference_types)

  true_positives += tp
  false_positives += fp
  false_negatives += fn
end


precision = (true_positives) / (true_positives + false_positives).to_f * 100
recall = (true_positives) / (true_positives + false_negatives).to_f * 100
f1 = 2 * precision * recall / (precision + recall)

puts '| %-25s | Precision | Recall     | F1          |' % " "
puts '| %-25s | --------- | ---------- | ----------- |' % ("-" * 25)
puts '| %-25s | %.1f      | %.1f       | %.1f        |' % [(" " * 25),precision,recall,f1]

