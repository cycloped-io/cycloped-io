#!/usr/bin/env ruby

require 'bundler/setup'
$:.unshift "lib"
$:.unshift "../category-mapping/lib"
require 'slop'
require 'colors'
require 'progress'
require 'csv'
require 'mapping/candidate'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f partitions.csv\n"+
    "Export results of pattern mapping."

  on :f=, :input, "File with centroids", required: true
  on :o=, :output, "File with mapping"
  on :x=, :offset, "Patterns offset", as: Integer, default: 0
  on :l=, :length, "Patterns count", as: Integer
  on :v, :verbose, "Verbose mode"
  on :s, :stats, "Output statistics"
  on :p=, :support, "Minimum support value for the mapping", as: Integer, default: 1
  on :b=, :blacklist, "Blacklist of abstract type"
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

index = -1
entropies = []
blacklist = []
if options[:blacklist]
  File.open(options[:blacklist]){|f| f.each{|l| blacklist << l.chomp } }
end
output = CSV.open(options[:output],"w") if options[:output]
Progress.start(`wc -l #{options[:input]}`.to_i) unless options[:verbose]
CSV.open(options[:input]) do |input|
  input.each do |row|
    index += 1
    Progress.step(1) unless options[:verbose]
    next if index < options[:offset]
    break if options[:length] && options[:length] + options[:offset] < index
    begin
      entity = row.shift
      presumed_support = row.shift.to_i
      total_support = 0
      candidates = row.each_slice(3).map do |tuple|
        next if blacklist.include?(tuple[1])
        candidate = Mapping::Candidate.new(*tuple,0)
        total_support += candidate.positive
        candidate
      end.compact
      total_support = [presumed_support,total_support].max
      candidates.each{|c| c.total = total_support }
      entropy = 0
      candidates.each do |candidate|
        entropy -= candidate.probability * Math::log(candidate.probability)
      end
      if output
        output_tuple = [entity,entropy.round(5)]
        candidates.each do |candidate|
          next if candidate.positive < options[:support]
          output_tuple.concat(candidate.to_a(:mle_probability))
        end
        output << output_tuple if output_tuple.size > 1
      end
      if options[:verbose]
        puts entity.hl(:blue)
        puts "Entropy %.3f" % entropy
        candidates.each do |candidate|
          str = ("- %.3f %s" % [candidate.probability,candidate.cyc_name])
          puts str
        end
      end
      entropies << [entropy,total_support]
      sleep(0.01) if options[:verbose]
    rescue Interrupt
      puts
      break
    end
  end
end
Progress.stop unless options[:verbose]
output.close if output

if options[:stats]
  mean = entropies.inject(0){|s,(e,sp)| s + e } / entropies.size
  deviation = Math::sqrt(entropies.inject(0){|s,(e,sp)| s + (mean - e) ** 2 }/(entropies.size-1))
  puts ("Entropy %.3f +/- %.3f" % [ mean, deviation ]).hl(:green)
  entropies.group_by{|e,sp| e.round(1) }.sort_by{|k,v| k }.each do |value,group|
    print "%.1f " % value
    puts "*" * (group.size/10)
  end
end
