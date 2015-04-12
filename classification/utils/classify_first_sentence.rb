#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
$:.unshift "../category-mapping/lib"
require 'slop'
require 'csv'
require 'progress'
require 'mapping/candidate'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -f mapping.csv -o results.csv\n" +
             "Export results of disambiguation of genus proxima against Cyc terms"

  on :f=, :mapping, "File with results of automatic mapping", required: true
  on :o=, :output, "Output file with disambiguation", required: true
end

begin
  options.parse
rescue Exception
  puts options
  exit
end

probabilities = []
unknowns = []
CSV.open(options[:output],"w") do |output|
  CSV.open(options[:mapping], "r:utf-8") do |input|
    puts "Exporting regular mappings"
    begin
      input.with_progress do |row|
        concept_name = row.shift
        types_with_support = []
        row.each do |element|
          case element
          when "T"
            types_with_support << []
          when /^\d+(\.\d+)?$/
            types_with_support.last << element.to_i
          else
            types_with_support.last << element
          end
        end

        output_tuple = [concept_name]
        unknown_support = []
        types_with_support.each do |tuple|
          type = tuple.shift
          candidates = tuple.each_slice(4).map{|t| Mapping::Candidate.new(*t) }
          candidates.each{|c| probabilities << c.probability }
          candidates.each{|c| unknown_support << c if c.total == 0 }
          candidates.each{|c| output_tuple.concat(c.to_a) if c.probability > 0 }
        end
        if output_tuple.size > 1
          output << output_tuple
        elsif unknown_support.size > 0
          unknowns << [concept_name,*unknown_support.map(&:to_a).flatten(1)]
        end
      end
    rescue Interrupt
      # do nothing - it's ok
    end
    puts "Exporting mappings with 'unknown' support"
    mean = (probabilities.inject(:+) / probabilities.size.to_f) / 2
    unknowns.each.with_progress do |tuple|
      (tuple[1..-1].size / 3).times do |index|
        tuple[3+index*3] = (mean / (tuple.size / 3).to_f).round(5)
      end
      output << tuple
    end
  end
end
