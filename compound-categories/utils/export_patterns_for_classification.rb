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
             "Export patterns for classification (classify_unambiguous_patterns.py)."

  on :m=, :reference, 'Reference classification', required: true
  on :i=, :classification, 'Automatic (verified) classification with entropy (float) in second column', required: true
  on :o=, :output, 'Output for classification', required: true
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
  input.with_progress do |name, *types|
    reference[name] = types.each_slice(2).to_a
  end
end

CSV.open(options[:output], "w:utf-8") do |output|
  CSV.open(options[:classification], "r:utf-8") do |input|
    input.with_progress do |name, entropy, *types|
      next if reference[name].nil?

      count = types.size/3
      type = types.each_slice(3).first
      cyc_id, cyc_name, probability = type
      if probability.nil?
        probability=0.0
      end

      reference_type = reference[name].first[1]
      if reference_type=='Thing'
        label=0
      else
        label=1
      end
      output << [label, entropy, probability, count, name]
    end
  end
end