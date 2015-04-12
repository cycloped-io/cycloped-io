#!/usr/bin/env ruby
# encoding: utf-8

require 'slop'
require 'progress'
require 'rdf'
require 'rdf/turtle'

# Converts short_abstracts.ttl to 2 files for Stanford parser.
# Time: 1h

opts = Slop.new do
  banner "Usage: #{$PROGRAM_NAME} -d short_abstracts -r resources -a abstracts"

  on :d=, 'short_abstracts', 'Short abstracts TTL file', required: true
  on :r=, 'resources', 'File where resources names will be written', required: true
  on :a=, 'abstracts', 'File where abstracts will be written', required: true
end
begin
  opts.parse
rescue Slop::MissingOptionError
  puts opts
  exit
end

short_abstracts = opts[:short_abstracts]
resources = opts[:resources]
abstracts = opts[:abstracts]

File.open(resources, "w") do |file1|
  File.open(abstracts, "w") do |file2|
    RDF::Reader.open(short_abstracts, :format => :ttl) do |reader|
      Progress.start(4004480) do
        reader.each_statement do |s|
          Progress.step do
            #puts s[0].to_s[28..-1], s[2]
            file1.write(s[0].to_s[28..-1].gsub('_',' ')+"\n")
            file2.write(s[2].value.gsub("\n",' ')+"\n")
          end
        end
      end
    end
  end
end
