#!/usr/bin/env ruby

require 'bundler/setup'
$:.unshift "lib"
require 'slop'
require 'progress'
require 'csv'
require 'colors'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f heads.csv -o filtered.csv\n"+
    "Filter out patterns based on entropy and posiotion of head.\n"

  on :f=, :input, "Input file with patterns and head", required: true
  on :o=, :output, "Output file with filtered out patterns", required: true
  on :e=, :entropy, "Maximum entropy of head value", default: 0.5, as: Float
  on :v, :verbose, "Verbose output"
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

def entropy(tuples)
  sum = tuples.each_slice(2).map(&:last).map(&:to_i).inject(:+)
  - tuples.each_slice(2).map{|k,v| v.to_f / sum}.inject(0){|s,e| e * Math.log(e) + s }
end

histogram = Hash.new(0)
CSV.open(options[:input],"r:utf-8") do |input|
  CSV.open(options[:output],"w") do |output|
    input.each do |pattern,support,*heads|
      begin
        pattern_entropy = entropy(heads)
        histogram[pattern_entropy.round(1)] += 1
        next if pattern_entropy > options[:entropy]
        best_head = heads.each_slice(2).sort_by{|k,v| -v.to_i }.first.first
        if best_head == ""
          puts "#{pattern} #{pattern_entropy.round(2)}".hl(:purple) if options[:verbose]
        elsif pattern =~ /#{best_head}/
          if pattern_entropy != 0 && options[:verbose]
            puts "#{pattern.hl(:green,best_head)} #{pattern_entropy.round(2)}"
          end
          output << [pattern,support,best_head]
        elsif options[:verbose]
          if pattern_entropy == 0
            puts "#{pattern} #{pattern_entropy.round(2)}".hl(:blue)
          else
            puts "#{pattern} #{pattern_entropy.round(2)}".hl(:yellow)
          end
        end
      rescue Interrupt
        puts
        break
      end
    end
  end
end
if options[:verbose]
  histogram.sort_by{|k,_| k }.each do |p_entropy,count|
    puts "#{p_entropy} : #{count}"
  end
end
