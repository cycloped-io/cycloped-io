#!/usr/bin/env ruby

require 'bundler/setup'
require 'csv'
require 'slop'
require 'progress'


options = Slop.new do
  banner "Usage: #{$PROGRAM_NAME} -p parsed_path -o output_path\n" +
             'Parses output of Stanford Parser to CSV'

  on :s=, 'sentences_path', 'Sentences in new lines', required: true
  on :p=, 'parsed_path', 'Parsed sentences by Stanford Parser', required: true
  on :o=, 'output_path', 'Path to output', required: true
end
begin
  options.parse
rescue Slop::MissingOptionError
  puts options
  exit
end

lines = []

CSV.open(options[:output_path], 'w') do |file_output|
  File.open(options[:sentences_path]) do |file_sentences|
    File.open(options[:parsed_path]) do |file_parsed|
      file_parsed.each do |line|
        if line == "\n"

          sentence = file_sentences.gets.strip
          while sentence==''
            file_output << []
            sentence = file_sentences.gets.strip
          end

          file_output << [lines[0].rstrip, lines[1..-1].join.rstrip]

          lines=[]
        elsif line == "(())\n"
          p line
          file_output << [nil, nil]
        else
          lines.push(line)
        end
      end

    end
  end
end