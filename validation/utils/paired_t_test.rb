#!/usr/bin/env ruby

require 'statsample'
require 'colors'
require 'slop'
require 'csv'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -a data1.csv -b data2.csv\n" +
    'Compute paired Student t-test to check statistical significance of the results'

  on :a=, :sample1, "Sample 1 (CSV)", required: true
  on :b=, :sample2, "Sample 2 (CSV)", required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

def paired_t_test(vector_a,vector_b)
  raise "Unequal vectors" if vector_a.size != vector_b.size
  vector_a = vector_a.to_scale
  vector_b = vector_b.to_scale
  puts "Mean %6.3f %6.3f" % [vector_a.mean,vector_b.mean]
  puts "Size %6i" % vector_a.size
  differences = vector_a.zip(vector_b).map{|a,b| a - b}.to_scale
  deviation = differences.sd / Math::sqrt(differences.size)
  probability = Statsample::Test::T.new(differences.mean, deviation, differences.size - 1).probability
  if probability < 0.05
    puts ("P two-tail %6.5f < 0.05" % probability).hl(:green)
  else
    puts ("P two-tail %6.5f >= 0.05" % probability).hl(:red)
  end
end

sample1 = []
CSV.open(options[:sample1]) do |input|
  input.each do |row|
    sample1 << row.first.to_f
  end
end
sample2 = []
CSV.open(options[:sample2]) do |input|
  input.each do |row|
    sample2 << row.first.to_f
  end
end
paired_t_test(sample1,sample2)

#if $0 == __FILE__
#  paired_t_test([20,20,19,16,15,17,14],[20,20.5,18.5,20,19,19,18])
#end
