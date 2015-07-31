#!/usr/bin/env ruby
# encoding: utf-8


require 'bundler/setup'
$:.unshift "../category-mapping/lib"
require 'rlp/wiki'
require 'progress'
require 'csv'
require 'slop'
require 'set'
require 'colors'
require 'cycr'
require 'mapping'
require 'experiment_arguments_log/auto'
require 'syntax'
require 'nouns/nouns'
require 'yajl'
require 'auto_serializer'
require 'dbm'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -i db.csv -o dbpedia \n" +
             "Converts classification (with probabilites) to dbm format."

  on :i=, :input, 'Classification in CSV', required: true
  on :o=, :output, 'Entities with classification in DBM', required: true
  on :n=, :name, 'Information name', required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end


db = DBM.open(options[:output])

information_name = options[:name]

CSV.open(options[:input]) do |input|
  input.with_progress do |name, *types|
    candidates={}
    types.each_slice(3).with_index do |tuple, index|
      cyc_id, cyc_name, probability = tuple
      candidates[information_name+index.to_s]={cyc_id => []}
    end
    db[name]=Yajl::Encoder.encode(candidates)
  end
end

db.close




