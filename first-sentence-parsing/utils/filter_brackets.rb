#!/usr/bin/env ruby

require 'bundler/setup'
require 'csv'
require 'slop'
require 'progress'

options = Slop.new do
  banner "Usage: #{$PROGRAM_NAME} -c parsed_definitions.csv -o fixed.csv\n"+
  'Removes brackets and others from sentences.'

  on :c=, 'sentences', 'Parsed definitions', required: true
  on :o=, 'output', 'Parsed definitions with fixed sentences (only)', required: true
end
begin
  options.parse
rescue Slop::MissingOptionError
  puts options
  exit
end

stats = Hash.new(0)

CSV.open(options[:sentences], 'r:utf-8') do |sentences|
  CSV.open(options[:output], 'w:utf-8') do |output|
    sentences.with_progress do |row|
      sentence = row[1].dup

      [/ ?\(+.*?\)+/, / ?\(.*/, / ?(Listen)?\/.*?\//, /.*?\[edit\]/, / ?\[+.*?\]+/, / ?\{+.*?\}+/, /.*?(\||\})\}/, /\{{2,}.*/, /^[^ ]*?\]{2,} ?/, /Error: Image is invalid or non-existent\./].each do |pattern|
        if row[1] =~ pattern
          stats[pattern.to_s] += 1
          sentence.gsub!(pattern,'')
        end
      end

      if sentence!=row[1]
        stats['changed'] += 1
        row[1] = sentence
      end
      output << row
    end
  end
end

p stats

# Last run result: {"(?-mix: ?\\(+.*?\\)+)"=>1314792, "(?-mix: ?\\(.*)"=>1319568, "changed"=>1331730, "(?-mix: ?(Listen)?\\/.*?\\/)"=>10105, "(?-mix: ?\\{+.*?\\}+)"=>3499, "(?-mix:.*?(\\||\\})\\})"=>4610, "(?-mix:\\{{2,}.*)"=>3356, "(?-mix:^[^ ]*?\\]{2,} ?)"=>679, "(?-mix: ?\\[+.*?\\]+)"=>5250, "(?-mix:.*?\\[edit\\])"=>1011, "(?-mix:Error: Image is invalid or non-existent\\.)"=>150}