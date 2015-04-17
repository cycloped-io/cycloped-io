#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
$:.unshift "lib"
require 'slop'
require 'csv'
require 'progress'
require 'mapping/candidate'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -f mapping.csv -o results.csv\n" +
    "Export results of disambiguation with local heuristics"

  on :m=, :mapping, "File with results of automatic mapping", required: true, as: Array
  on :o=, :output, "Output file with mapping and MLE probabilities", required: true
  on :p=, :map_output, "Output file with mapping and MAP probabilities", required: true
  on :w=, :winner_output, "Output file with mapping winner-takes-all", required: true
  on :l=, :limit, "Limit reading of concepts to first n entries", as: Integer, default: 0
end

begin
  options.parse
rescue Exception => ex
  puts ex
  puts options
  exit
end

mapping = {}
total = 0

if options[:map_output]
  map_output = CSV.open(options[:map_output],"w")
end
winner_output = CSV.open(options[:winner_output],"w")

CSV.open(options[:output],"w") do |output|
  options[:mapping].each do |file_name|
    puts "Processing #{file_name}"
    CSV.open(file_name,"r:utf-8") do |input|
      index = 0
      input.with_progress do |tuple|
        index += 1
        break if options[:limit] > 0 && index >= options[:limit]
        row = tuple.dup
        category_name = row.shift
        mapped_name = row.shift
        if mapped_name == "_PLUS_ONE_"
          output << tuple
          map_output << tuple if map_output
          winner_output << tuple
          next
        end
        candidates = []
        row.each_slice(4) do |tuple|
          candidate = Mapping::Candidate.new(*tuple)
          if candidate.probability > 0
            candidates << candidate
            total += 1
          end
        end
        mapping[[category_name,mapped_name]] = candidates
      end
    end
  end
  mean = mapping.inject(0){|s,(k,vs)| s + vs.inject(0){|ss,v| ss + v.mle_probability } } / total.to_f
  variance = mapping.inject(0){|s,(k,vs)| s + vs.inject(0){|ss,v| ss + (mean - v.mle_probability) ** 2 } } / (total.to_f - 1)
  Mapping::Candidate.mean_probability = mean
  Mapping::Candidate.probability_variance = variance

  puts "alpha / beta %.2f %.2f" % [Mapping::Candidate.alpha,Mapping::Candidate.beta]

  mapping.each do |(category_name,mapped_name),candidates|
    if candidates.size >= 1
      output_tuple = [category_name]
      map_tuple = [category_name]

      candidates.sort_by{|c| - c.probability }.each do |candidate|
        output_tuple.concat(candidate.to_a(:mle_probability))
        map_tuple.concat(candidate.to_a(:map_probability))
      end

      max_probability = candidates.max_by{|c| c.probability}.probability
      winners = candidates.select{|c| c.probability==max_probability}
      winner_tuple = [category_name]
      winners.sort_by{|c| - c.probability }.each do |candidate|
        winner_tuple.concat([candidate.cyc_id,candidate.cyc_name, 1.0/winners.size])
      end

      output << output_tuple
      map_output << map_tuple if map_output
      winner_output << winner_tuple
    end
  end
end
map_output.close if map_output
winner_output.close