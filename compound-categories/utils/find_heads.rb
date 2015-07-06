#!/usr/bin/env ruby
# encding: utf-8

require 'bundler/setup'
$:.unshift "../category-mapping/lib"
require 'set'
require 'progress'
require 'csv'
require 'slop'
require 'cycr'
require 'mapping'
require 'rlp/wiki'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -f patterns.csv -d db -o heads.csv\n" +
             "Identify syntactic heads in patterns"

  on :f=, :input, "File with patterns and categories", required: true
  on :o=, :output, "File with syntactic heads", required: true
  on :d=, :database, "ROD Wikipedia database", required: true
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

CSV.open(options[:input]) do |input|
  CSV.open(options[:output], "w") do |output|
    index = 0
    input.with_progress do |row|
      pattern = row.shift
      support = row.shift.to_i
      break if support < 20
      histogram = Hash.new(0)
      row.each.with_index do |category_id,index|
        category = Category.find_by_wiki_id(category_id.to_i)
        next unless category
        break if index >= 1000
        next unless category.head_tree
        head_noun = category.head_tree.find_head_noun
        next unless head_noun
        histogram[head_noun.to_literal] += 1
        #puts "#{category.name} : #{category.head_tree.find_head_noun.to_literal}"
      end
      sorted = histogram.sort_by{|_,v| -v }
      output << [pattern,support,*sorted.flatten]
      index += 1
    end
  end
end

Database.instance.close_database
