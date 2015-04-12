#!/usr/bin/env ruby

require 'bundler/setup'
$:.unshift "lib"
require 'slop'
require 'csv'
require 'cycr'
require 'progress'
require 'mapping'
require 'set'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f mapping.csv [-c unique_ids] [-d disambiguated_unique_ids]"
    "Displays the statistics regarding category coverage of the mapping"

  on :f=, :mapping, "File with results of automatic mapping using local heuristics", required: true
  on :c=, :unique_ids, "Output file with unique ids of candidate Cyc terms"
  on :o=, :disambiguated_ids, "Output file with unique ids of mapped and disambiguated Cyc terms"
  on :l=, :limit, "Limit computation to first n categories", as: Integer
end

begin
  options.parse
rescue Exception
  puts options
  exit
end

total = 0
ambiguous_count = 0
not_mapped_count = 0
not_disabiguated_count = 0
disambiguated = 0
one_without_support = 0

ambig_instance_examples = []

histogram = Hash.new(0)
unique_cyc_ids = Set.new
all_unique_cyc_ids = Set.new
probabilities = []
CSV.open(options[:mapping]) do |input|
  input.with_progress do |row|
    total += 1
    break if options[:limit] && total > options[:limit]
    category_name = row.shift
    mapped_name = row.shift
    ambiguous = false
    instances = []
    disambiguations = []
    if row.empty?
      not_mapped_count += 1
      next
    end
    row.each_slice(4) do |cyc_id,cyc_name,positive,negative|
      support = positive.to_f
      negative = negative.to_f
      all_unique_cyc_ids << cyc_id
      disambiguations << cyc_id if support > 0
      next
      if negative > 0
        probabilities << support/negative
      else
        probabilities << 0
      end
    end
    histogram[row.size/4] += 1
    if disambiguations.size == 0
      if row.size / 4 > 1
        not_disabiguated_count += 1
      else
        one_without_support += 1
      end
    elsif disambiguations.size > 1
      ambiguous_count += 1
    else
      disambiguated += 1
      unique_cyc_ids << disambiguations.first
    end
  end
end

def with_percent(value,total)
  "%i | %.1f%% " % [value, (value / total.to_f * 100)]
end

mean = probabilities.inject(0){|s,e| s + e } / probabilities.size.to_f
variance = probabilities.inject(0){|s,e| s + (mean - e) ** 2 } / (probabilities.size.to_f - 1)
puts "0 candidates | #{with_percent(histogram[0],histogram.values.inject(:+))}"
puts "1 candidate | #{with_percent(histogram[1],histogram.values.inject(:+))}"
puts "2 candidate | #{with_percent(histogram[2],histogram.values.inject(:+))}"
above_2 = histogram.values.inject(:+) - histogram[0] - histogram[1] - histogram[2]
puts ">2 candidate | #{with_percent(above_2,histogram.values.inject(:+))}"

puts <<END
|  Categories                 | count | percent |
|-----------------------------|------:|--------:|
|  Total (non-administrative & plural head)                   | #{with_percent(total,total)} |
|  Unambig. mapped                                            | #{with_percent(disambiguated,total)} |
|  Unambig. without support                                   | #{with_percent(one_without_support,total)} |
|  Not mapped (no name match)                                 | #{with_percent(not_mapped_count,total)} |
|  Not disambiguated (name match, no local disambiguation)    | #{with_percent(not_disabiguated_count,total)} |
|  Ambiguous (multiple results)                               | #{with_percent(ambiguous_count,total)} |
|  Mean probability                                           | #{mean.round(3)} | |
|  Probability variance                                       | #{variance.round(3)} | |
|  Unique disamb. cyc terms:                                  | #{unique_cyc_ids.size} | |
|  Unique cyc terms:                                          | #{all_unique_cyc_ids.size} | |
END
if options[:unique_ids]
  File.open(options[:unique_ids],"w") do |output|
    all_unique_cyc_ids.each{|id| output.puts id }
  end
end
if options[:disambiguated_ids]
  File.open(options[:disambiguated_ids],"w") do |output|
    unique_cyc_ids.each{|id| output.puts id }
  end
end
