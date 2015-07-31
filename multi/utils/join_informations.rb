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
  banner "#{$PROGRAM_NAME}\n" +
             "Joins DBM encoded informations."

  on :a=, :file_a, 'First file', required: true
  on :b=, :file_b, 'Second file', required: true
  on :o=, :output, 'Output file', required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

db_a = DBM.open(options[:file_a])
db_b = DBM.open(options[:file_b])

db_output = DBM.open(options[:output])

db_a.with_progress do |key, data|
  data_a = Yajl::Parser.parse(data)
  if db_b.include?(key)
    data_b = Yajl::Parser.parse(db_b[key])
    data_a.merge!(data_b)
  end
  db_output[key]=Yajl::Encoder.encode(data_a)
end

db_b.with_progress do |key, data|
  next if db_a.include?(key)
  db_output[key]=data
end