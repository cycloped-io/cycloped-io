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
  banner "#{$PROGRAM_NAME} -f classification.csv -t types.csv -o new_classification.csv\n" +
             "Assign Cyc high-level concepts (determined empirically) to the entities"

  on :f=, :input, "File with entities classification", required: true
  on :o=, :output, "File with classification to high-level concepts", required: true
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
errors = 0
CSV.open(options[:input]) do |input|
  CSV.open(options[:output], "w") do |output|
    input.with_progress do |row|
      header = row.shift(options[:fields])

      types = Hash.new(0)
      row.each_slice(3) do |cyc_id, cyc_name, support|
        mid = mapping[cyc_id]
        if mid.nil?
          #p [cyc_id, cyc_name]
          errors += 1
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
puts errors
