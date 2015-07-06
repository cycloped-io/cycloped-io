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
  banner "#{$PROGRAM_NAME} -f mapping.csv -t types.csv -o new_mapping.csv\n" +
             "Assign Cyc high-level concepts to pattern mapping"

  on :f=, :input, "File with pattern mapping", required: true
  on :o=, :output, "File with mapping to high-level concepts", required: true
  on :t=, :types, "Cyc high-level concepts", required: true
  on :F=, :fields, "Number of header fields in each row", default: 2, as: Integer
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end


mapping = {}
CSV.open(options[:types]) do |input|
  input.each do |cyc_id, cyc_name, _, mid_cyc_id, mid_cyc_name|
    mapping[cyc_id] = [mid_cyc_id, mid_cyc_name]
  end
end

errors = Hash.new(0)
CSV.open(options[:input]) do |input|
  CSV.open(options[:output], "w") do |output|
    input.with_progress do |row|
      header = row.shift(options[:fields])

      types = Hash.new(0)
      row.each_slice(3) do |cyc_id, cyc_name, support|
        mid = mapping[cyc_id]
        if mid.nil?
          errors[cyc_name] += 1
          next
        end
        types[mid]+=support.to_i
      end

      tuple = []
      types.sort_by { |mid, support| support }.reverse.each do |mid, support|
        tuple << mid+[support]
      end
      output << header+tuple.flatten
    end
  end
end
errors.sort_by{|_,v| -v }.each do |k,v|
  puts "#{k} : #{v} "
end
