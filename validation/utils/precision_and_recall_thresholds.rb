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
  banner "#{$PROGRAM_NAME} -m reference.csv -i classification.csv\n" +
             "Counts precision, recall and F1 measure in relation to entropy threshold."

  on :m=, :reference, 'Reference classification', required: true
  on :i=, :classification, 'Automatic (verified) classification with entropy (float) in second column', required: true
  on :v=, :mode, 'Entropy (e) or probability (p) of the best', required: true
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

mismatch_file = CSV.open(options[:mismatch], "w") if options[:mismatch]

cyc_names = {}

reference = {}
CSV.open(options[:reference], "r:utf-8") do |input|
  input.with_progress do |name, *types|
    types.each_slice(2) do |cyc_id, cyc_name|
      cyc_names[cyc_id]=cyc_name
    end
    types = types.each_slice(2).map { |cyc_id, cyc_name| cyc_id }
    reference[name] = types
  end
end



mismatch_file = CSV.open(options[:mismatch], "w") if options[:mismatch]



classification = {}
CSV.open(options[:classification], "r:utf-8") do |input|
  input.with_progress do |name, entropy, *types|
    next if reference[name].nil?
    types.each_slice(3) do |cyc_id, cyc_name, proba|
      cyc_names[cyc_id]=cyc_name
    end
    type = types.each_slice(3).first #.map { |cyc_id, cyc_name, probability| cyc_id }.first
    cyc_id, cyc_name, probability = type

    if options[:mode]=="e"
      value=entropy.to_f
    elsif options[:mode]=="p"
      value=probability.to_f
    end
    classification[name] = [value, cyc_id]
  end
end

puts "Coverage: %s" % classification.size

scores = {}

sorted_reference = reference.sort_by { |name, types|  classification[name].nil? ? 0.0 : classification[name][0] }
sorted_reference.reverse! if options[:mode]=="e"


measures = {'s' => SimpleScore, 'a' => AprosioScore, 'n' => AprosioScoreNormalized}
scorer1 = measures[options[:score]].new(name_service)
scorer2 = measures[options[:score]].new(name_service)

double_scores = {}

sorted_reference.with_progress do |name, reference_types|
  reference_type = reference_types.first
  value, type=classification[name]
  if type.nil?
    predicted_types = []
  else
    predicted_types = [type]
  end

  tp,fp,fn = scorer1.score(predicted_types, [reference_type])
  tp2,fp2,fn2 = scorer2.score([Thing.id], [reference_type])
  double_scores[name] = [tp,fp,fn,tp2,fp2,fn2]
end

sorted_reference.with_progress do |name, reference_types|
  value, type=classification[name]
  if value.nil?
    value=0.0 # ?
  end

  tp,fp,fn,tp2,fp2,fn2 = double_scores[name]

  scorer1.true_positives -= tp
  scorer1.false_positives -= fp
  scorer1.false_negatives -= fn
  scorer1.true_positives += tp2
  scorer1.false_positives += fp2
  scorer1.false_negatives += fn2

  scores[value]=[scorer1.precision, scorer1.recall, scorer1.f1]
end



mismatch_file.close if mismatch_file


puts '| %-25s | Value     | Precision | Recall     | F1          |' % " "
puts '| %-25s | --------- | --------- | ---------- | ----------- |' % ("-" * 25)

scores.sort_by{|value,score| value}.each do |value,score|
  precision, recall, f1 =score
  puts '| %-25s | %.3f      | %.1f      | %.1f       | %.1f        |' % [(" " * 25), value, precision, recall, f1]
end



