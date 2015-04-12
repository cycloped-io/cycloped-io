#!/usr/bin/env ruby
# encding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
require 'set'
require 'progress'
require 'csv'
require 'slop'
require 'colors'
require 'cycr'
require 'mapping'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -d db -f terms.csv -o articles.csv [-p port] [-h host]\n" +
    "Export Wikipedia articles that correspond to the Cyc terms. No disambiguation is performed."

  on :d=, :database, "ROD database", required: true
  on :f=, :input, "Input file with Cyc terms", required: true
  on :o=, :output, "Output file with Cyc terms and corresponding Wikipedia articles", required: true
  on :p=, :port, "Cyc port", as: Integer, default: 3601
  on :h=, :host, "Cyc host", default: 'localhost'
  on :v, :verbose, "Verbose diagnostic messages"
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
cyc = Cyc::Client.new(port: options[:port], host: options[:host], cache: true)
name_service = Mapping::Service::CycNameService.new(cyc)

mapped_categories = []
CSV.open(options[:input],"r:utf-8") do |input|
  CSV.open(options[:output],"w") do |output|
    input.with_progress do |row|
      term_id = row.shift
      term = name_service.find_by_id(term_id)
      labels = Array[name_service.canonical_label(term)]
      labels.concat(name_service.labels(term))
      output << labels.compact.map do |label|
        Concept.find_with_redirect(label[0].upcase + label[1..-1])
      end.compact.map(&:name).uniq.unshift(term_id).unshift(term.to_ruby.to_s)
    end
  end
end
