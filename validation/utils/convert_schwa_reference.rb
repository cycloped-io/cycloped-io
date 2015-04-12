#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'slop'
require 'csv'
require 'progress'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -i reference.tsv -o reference.csv -l language\n" +
    'Convert SCHWA classification in TSV format to our standard CSV.'

  on :i=, :input, 'Reference classification in SCHWA fromat (TSV)', required: true
  on :o=, :output, 'Reference classification in our format (CSV)', required: true
  on :l=, :language, 'Language selected for conversion (en by default)', default: 'en'
end


begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

header_visited = false
CSV.open(options[:input],"r:utf-8",col_sep: "\t") do |input|
  CSV.open(options[:output],"w") do |output|
    input.with_progress do |language,name,type|
      if !header_visited
        header_visited = true
        next
      end
      next if language != options[:language]
      output << [name.gsub("_"," "),type]
    end
  end
end
