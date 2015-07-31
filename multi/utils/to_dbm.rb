#!/usr/bin/env ruby
# encoding: utf-8


require 'bundler/setup'
$:.unshift '../category-mapping/lib'
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
  banner "#{$PROGRAM_NAME} -i _candidates_preprocessed.csv -o _candidates \n" +
             'Converts CSV to DBM format.'

  on :i=, :input, 'Entities with assigned candidates in CSV', required: true
  on :o=, :output, 'Entities with assigned candidates in DBM', required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end


db = DBM.open(options[:output])

CSV.open(options[:input]) do |input|
  input.with_progress do |name, candidates|
    db[name]=candidates
  end
end

db.close