#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
$:.unshift "lib"
require 'slop'
require 'csv'
require 'cycr'
require 'progress'
require 'jaro_winkler'
require 'mapping'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -f mapping.csv -o results.csv\n" +
    "Export results of disambiguation with local heuristics"

  on :m=, :mapping, "File with results of automatic mapping", required: true, as: Array
  on :o=, :output, "Output file with mapping for winner-takes-all", required: true
  on :a=, :map_output, "Output file with mapping and MAP probabilities"
  on :e=, :mle_output, "Output file with mapping MLE probabilities"
  on :l=, :limit, "Limit reading of concepts to first n entries", as: Integer, default: 0
  on :p=, :port, "Cyc port", as: Integer, default: 3601
  on :h=, :host, "Cyc host", default: 'localhost'
end

begin
  options.parse
rescue Exception => ex
  puts ex
  puts options
  exit
end

cyc = Cyc::Client.new(port: options[:port], host: options[:host], cache: true)
name_service = Mapping::Service::CycNameService.new(cyc)
mapping = {}
total = 0

if options[:map_output]
  map_output = CSV.open(options[:map_output],"w")
end
if options[:mle_output]
  mle_output = CSV.open(options[:mle_output],"w")
end

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
          new_row = [category_name]+row[0..2] #TODO
          output << new_row
          map_output << new_row if map_output
          mle_output << new_row
          next
        end
        candidates = []
        row.each_slice(4) do |tuple|
          candidate = Mapping::Candidate.new(*tuple)
          #if candidate.probability > 0
            candidates << candidate
            total += 1
          #end
        end
        # The mapping may contain duplicate entries
        # TODO we should handle that !!!
        mapping[[category_name,mapped_name]] ||= candidates
      end
    end
  end
  mean = mapping.inject(0){|s,(k,vs)| s + vs.inject(0){|ss,v| ss + v.mle_probability } } / total.to_f
  variance = mapping.inject(0){|s,(k,vs)| s + vs.inject(0){|ss,v| ss + (mean - v.mle_probability) ** 2 } } / (total.to_f - 1)
  Mapping::Candidate.mean_probability = mean
  Mapping::Candidate.probability_variance = variance

  puts "alpha / beta %.2f %.2f" % [Mapping::Candidate.alpha,Mapping::Candidate.beta]

  mapping.each.with_progress do |(category_name,mapped_name),candidates|
    if candidates.size >= 1
      mle_tuple = [category_name]
      map_tuple = [category_name]

      candidates.sort_by{|c| - c.probability }.each do |candidate|
        mle_tuple.concat(candidate.to_a(:mle_probability))
        map_tuple.concat(candidate.to_a(:map_probability))
      end

      max_probability = candidates.max_by{|c| c.probability}.probability
      winners = candidates.select{|c| c.probability==max_probability}
      best = winners.map do |candidate|
        label = name_service.canonical_label(name_service.find_by_id(candidate.cyc_id))
        if label.nil?
          nil
        else
          [candidate,JaroWinkler.r_distance(category_name,label,ignore_case: true)]
        end
      end.compact.sort_by{|c,d| -d }.first
      if best
        best = best.first
      else
        best = winners.first
      end
      output << [category_name,best.cyc_id,best.cyc_name,best.probability]
      map_output << map_tuple if map_output
      mle_output << winner_tuple if mle_output
    end
  end
end
map_output.close if map_output
mle_output.close if mle_output
