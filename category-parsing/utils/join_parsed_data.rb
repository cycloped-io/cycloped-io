#!/usr/bin/env ruby

require 'bundler/setup'
require 'csv'
require 'slop'
require 'progress'


opts = Slop.new do
  banner "Usage: parse_category_names.rb -s sentences_path -p parsed_path -o output_path\n" +
    "Exporst results of disambiguation with local heuristics"

  on 's', 'sentences_path', 'Sentences in new lines', argument: :mandatory, required: true
  on 'p', 'parsed_path', 'Parsed sentences by Stanford Parser', argument: :mandatory, required: true
  on 'o', 'output_path', 'Path to output', argument: :mandatory, required: true
end
begin
  opts.parse
rescue Slop::MissingOptionError
  puts opts
  exit
end

sentences_path = opts[:sentences_path]
parsed_path = opts[:parsed_path]
output_path = opts[:output_path]

# Lloyds Bank plc v Rosset [1990 1990] UKHL 14, <U+2029>[1991 1991]<U+2029> AC 107 is an important case in English property law dealing with the rights of cohabitees.
lines = []
file_parsed = File.new(parsed_path, "r")
file_sentences = File.new(sentences_path, "r")
#file_sentences = CSV.open(sentences_path, "r")

file_output = CSV.open(output_path, 'w')

file_parsed.each do |line|
  if line == "\n"

    row = [file_sentences.gets.strip]
    while row.first==''
      file_output << []
      row = [file_sentences.gets.strip]
    end
    row.push lines[0].rstrip
    row.push lines[1..-1].join.rstrip
    # #
    #  if !row[1].include?(row[0].split(' ').first)
    #    puts row
    #    puts
    #  end

    file_output << row

    lines=[]
  elsif line == "(())\n"
    p line
    file_output << [file_sentences.gets,nil,nil]
  else
    lines.push(line)
  end
end

file_parsed.close
file_sentences.close
file_output.close


