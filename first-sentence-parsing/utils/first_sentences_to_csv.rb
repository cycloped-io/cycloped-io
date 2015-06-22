#!/usr/bin/env ruby

require 'bundler/setup'
require 'slop'
require 'progress'
require 'rlp/wiki'
require 'cycr'
require 'colors'
require 'csv'
require 'set'
require 'rod/rest'




options = Slop.new do
  banner "#{$PROGRAM_NAME} -o mapping.csv [-p port] [-h host] [-c c:r] [-d database]\n"+
             "Map Wikipedia articles types (genus proximum) to Cyc terms."

  on :d=, :database, "ROD database with Wikipedia data", required: true

end

begin
  options.parse
rescue
  puts options
  exit
end

include Rlp::Wiki


Database.instance.open_database(options[:database])

Concept.with_progress do |concept|
  p concept.definition
end

Database.instance.close_database
