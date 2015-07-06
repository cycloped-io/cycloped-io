#!/usr/bin/env ruby

require 'bundler/setup'
$:.unshift "lib"
require 'slop'
require 'progress'
require 'csv'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f candidates.csv -o mapping.csv\n"+
    "Export results of direct mapping of patterns to terms"

  on :f=, :input, "File with pattern candidate mappings", required: true
  on :o=, :output, "Output file with pattern mapping", required: true
  on :s=, :support, "Minimum support of the candidate mapping", as: Integer, default: 10
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

def entropy(tuples)
  entropy = tuples.each_slice(4).reject{|t| t[-2] == "0" }.map{|_,_,p,t| p.to_i / t.to_f }.inject(0.0){|s,e| s - e * Math.log(e) }
  entropy.nan? ? 0 : entropy.round(3)
end

patterns = Hash.new{|h,e| h[e] = [] }
CSV.open(options[:input],"r:utf-8") do |input|
  CSV.open(options[:output],"w") do |output|
    input.with_progress do |pattern,head,support,*tuples|
      pattern_entropy = entropy(tuples)
      tuples.each_slice(4).sort_by{|_,_,p,_| -p.to_i }.each do |cyc_id,cyc_name,positive,total|
        break if positive.to_i < options[:support]
        output << [pattern,support,pattern_entropy,cyc_id,cyc_name,positive]
        break
      end
    end
  end
end
