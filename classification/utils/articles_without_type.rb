#!/usr/bin/env ruby
# encding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
require 'set'
require 'progress'
require 'csv'
require 'slop'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -d db -f classification.csv -o missing.csv\n" +
    "Export regular articles lacking classification."

  on :d=, :database, "Rod database", required: true
  on :f=, :input, "Input file with article classification", required: true
  on :o=, :output, "Output file with list of articles missing classification", required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

include Rlp::Wiki
Database.instance.open_database(options[:database])

classification = Set.new
puts "Reading classification"
CSV.open(options[:input],"r:utf-8") do |input|
  input.with_progress do |article_name,*rest|
    classification << article_name
  end
end
missing = total = 0
CSV.open(options[:output],"w") do |output|
  Concept.each.with_progress do |concept|
    next unless concept.regular?
    total += 1
    next unless classification.include?(concept.name)
    missing += 1
    output << concept.name
  end
end
Database.instance.close_database
puts "missing/total %i/%i/%.1f" % [missing,total,missing*100/total.to_f]
