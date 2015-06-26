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


options = Slop.new do
  banner "#{$PROGRAM_NAME} -f classification.csv -t types_classification.csv -o new_classification.csv\n" +
             'Assigns high-level concepts and choose the most supported.'

  on :f=, :input, "File with entities classification", required: true
  on :o=, :output, "File with classification to high-level concepts", required: true
  on :t=, :types, "Cyc high-level concepts classification", required: true
  on :m=, :method, "Voting method: f - frequency (default), e - probability error, s - probability sum, a - (frequency, probability sum), p - maximum probability", default: 'f'
  on :v, :verbose, "Turn on verbose mode"
  on :s, :simple, "Read data in simple format without probability"
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end



types_classification = {}
CSV.open(options[:types]) do |input|
  input.with_progress do |collection_id, collection_name, sth, type_id, type_name|
    next if type_id.nil?
    types_classification[collection_id] = [type_id, type_name]
    types_classification[type_id] = [type_id, type_name] # error in classification data?
  end
end


slices = 3
if options[:simple]
  slices = 2
end

stats = Hash.new(0)

CSV.open(options[:input], 'r:utf-8') do |input|
  CSV.open(options[:output], 'w:utf-8') do |output|
    input.with_progress do |row|
      name = row.shift
      probabilities = Hash.new { |h, k| h[k] = [] }
      map = Hash.new{|h,e| h[e] = [] }

      row.each_slice(slices) do |cyc_id, cyc_name, probability|
        probability = 1.0 if options[:simple]
        if !types_classification.include?(cyc_id)
          #puts cyc_id, cyc_name
          next
        end
        probabilities[types_classification[cyc_id]] << probability.to_f
        map[types_classification[cyc_id]] << cyc_name
      end
      if probabilities.empty?
        # p name, row
        stats['no candidates']+=1
        next
      end

      if options[:method] == 'f'
        measure=probabilities.map { |type, probs| [type, [probs.size]] }
      elsif options[:method] == 'e'
        measure=probabilities.map { |type, probs| [type, [1.0-probs.map { |v| 1-v }.reduce(:*)]] }
      elsif options[:method] == 's'
        measure=probabilities.map { |type, probs| [type, [probs.reduce(:+)]] }
      elsif options[:method] == 'a'
        measure=probabilities.map { |type, probs| [type, [probs.size, probs.reduce(:+)]] }
      elsif options[:method] == 'p'
        measure=probabilities
      end

      sorted = measure.sort_by { |type, value| value }.reverse
      if options[:verbose]
        map.each do |(_,name),concepts|
          puts "#{name}: #{concepts.uniq.join(", ")} #{concepts.size}"
          h1 = Hash.new(0)
          concepts.each{|c| h1[c] += 1}
          h1.sort_by{|k,v| -v }.each{|k,v| puts "#{k}, #{v}" }
        end
      end
      best_value = sorted.first[1]
      winners = sorted.select { |type, value| value==best_value }.map { |type, value| type }

      if winners.size>1
        stats['more than 1 type assigned']+=1
      else
        stats['1 type assigned']+=1
      end
      output << [name, *winners.flatten]
    end
  end
end
p stats
