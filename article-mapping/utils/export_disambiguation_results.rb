#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
$:.unshift "lib"
require 'slop'
require 'csv'
require 'cycr'
require 'progress'
require 'mapping'
require 'rlp/wiki'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -f mapping.csv -c candidates.csv -o results.csv -d database [-h host] [-p port]\n" +
    "Export results of disambiguation of articles against Cyc terms"

  on :f=, :mapping, "File with support values for mapping", required: true
  on :o=, :output, "Output file with disambiguation results", required: true
end

begin
  options.parse
rescue Exception
  puts options
  exit
end

include Rlp::Wiki

puts "Reading support"
articles_to_candidates = Hash.new{|h,e| h[e] = [] }
ids_to_articles = Hash.new{|h,e| h[e] = [] }
CSV.open(options[:mapping], "r:utf-8") do |input|
  input.with_progress do |row|
    article_name = row.shift
    row.each_slice(4) do |tuple|
      candidate = Mapping::Candidate.new(*tuple)
      next if candidate.positive == 0
      articles_to_candidates[article_name] << candidate
      ids_to_articles[candidate.cyc_id] << article_name
    end
  end
end

puts "Disambiguating"
disambiguated = Hash.new{|h,e| h[e] = [] }
ids_to_articles.each do |id,articles|
  with_candidates = articles.map{|a| [a,articles_to_candidates[a].find{|c| c.cyc_id == id }]}.sort do |a,b|
    if a[1].probability == b[1].probability
      b[1].positive - a[1].positive
    else
      b[1].probability - a[1].probability
    end
  end
  if with_candidates.size == 1 || with_candidates[0][1].probability > with_candidates[1][1].probability ||
      with_candidates[0][1].probability == with_candidates[1][1].probability && with_candidates[0][1].positive > with_candidates[1][1].positive
    disambiguated[with_candidates[0][0]] << with_candidates[0][1]
  else
    best_candidate = with_candidates.first[1]
    with_candidates.each do |article,candidate|
      break if candidate.probability < best_candidate.probability || candidate.positive < best_candidate.positive
      disambiguated[article] << candidate
    end
  end
end

puts "Exporting"
CSV.open(options[:output],"w") do |output|
  disambiguated.each.with_progress do |article,candidates|
    output << [article,*candidates.sort_by{|c| - c.probability}.map(&:to_a).flatten(1)]
  end
end
