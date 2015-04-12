#!/usr/bin/env ruby

require 'bundler/setup'
$:.unshift "lib"
require 'slop'
require 'progress'
require 'rlp/wiki'
require 'csv'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -d database -f patterns.csv -o matches.csv -x offset -l length\n"+
    "Match patterns against categories"

  on :d=, :database, "ROD Wikipedia database", required: true
  on :f=, :input, "File with patterns", required: true
  on :o=, :output, "Output file", required: true
  on :x=, :offset, "Categories offset", as: Integer, default: 0
  on :l=, :length, "Categories count", as: Integer
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
patterns_list = []
CSV.open(options[:input],"r:utf-8") do |input|
  input.with_progress do |pattern,*rest|
    if pattern =~ /\bX\b/
      regexp = Regexp.escape($`) + "(.*)" + Regexp.escape($')
    elsif pattern =~ /\bN(\b|.\b)/
      regexp = Regexp.escape($`) + "(\\d*)" + $1 + Regexp.escape($')
    else
      next
    end
    patterns_list << [pattern,regexp]
  end
end
pattern_regexps = []
# long patterns first
patterns_list.sort_by!{|p,_| -p.size}
patterns_list.each do |pattern,regexp|
  pattern_regexps << regexp
end

puts "Pattern construction..."
super_patterns = []
pattern_regexps.size.times.with_progress do |index|
  super_patterns << Regexp.new("\\A(?:#{pattern_regexps[index..-1].map{|p| "(?:#{p})" }.join("|")})\\z")
end
puts "done"

if options[:length]
  Progress.start(options[:length])
else
  Progress.start(Category.count - options[:offset])
end

count = 0
CSV.open(options[:output],"w") do |output|
  Category.each.with_index do |category,index|
    next if index < options[:offset]
    break if options[:length] && index > options[:offset] + options[:length]
    Progress.step(1)
    indices = []
    pattern_start_index = 0
    begin
      if matched = category.name.match(super_patterns[pattern_start_index])
        pattern_index,matched_string = matched.to_a[1..-1].map.with_index{|m,i| break [i,m] if m }
        pattern_index += pattern_start_index
        pattern_start_index = pattern_index + 1
        indices << [pattern_index,matched_string]
      end
    end while matched && pattern_start_index < super_patterns.size
    unless indices.empty?
      output << [category.name] + indices.map{|i,m| [patterns_list[i].first,m] }.flatten
      count += 1
    end
  end
end
Progress.stop
puts "Matched/total #{count}/#{Category.count}"
Database.instance.close_database
