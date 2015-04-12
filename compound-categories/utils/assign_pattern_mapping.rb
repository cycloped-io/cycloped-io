#!/usr/bin/env ruby

require 'bundler/setup'
$:.unshift "lib"
require 'slop'
require 'progress'
require 'csv'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f pattern_mapping.csv -m matches.csv -o category_mapping.csv\n"+
    "Assign pattern mappings to categories"

  on :f=, :input, "File with pattern mapping", required: true
  on :m=, :matches, "File with pattern matches", required: true
  on :o=, :output, "Output file with category mapping", required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

patterns = Hash.new{|h,e| h[e] = [] }
CSV.open(options[:input],"r:utf-8") do |input|
  input.with_progress do |pattern,*tuples|
    tuples.each_slice(3) do |cyc_id,cyc_name,probability|
      patterns[pattern] << [cyc_id,cyc_name,probability.to_f]
    end
  end
end

total = 0
count = 0
CSV.open(options[:output],"w") do |output|
  CSV.open(options[:matches],"r:utf-8") do |input|
    input.with_progress do |category,*matches|
      output_tuple = [category]
      matches.each_slice(2) do |pattern,match|
        next unless patterns.has_key?(pattern)
        patterns[pattern].each do |tuple|
          output_tuple.concat(tuple)
        end
      end
      if output_tuple.size > 1
        output << output_tuple
        count += 1
      end
      total += 1
    end
  end
end
Progress.stop
puts "Matched/total #{count}/#{total}"
