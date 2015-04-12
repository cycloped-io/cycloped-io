#!/usr/bin/env ruby

require 'bundler/setup'
require 'rlp/wiki'
$:.unshift 'lib'
require 'slop'
require 'csv'
require 'cycr'
require 'progress'
require 'mapping/bidirectional_map'
require 'mapping'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -a reference.csv -b validated.csv [-i intersection.csv] [-c conflicts.csv] \n" +
    "[-d missing_in_reference.csv] [-e missing_in_validated.csv]\n" +
    "Computes conflicts between SD and A.Pohl mappings."

  on :a=, :reference, "File with reference mapping", required: true
  on :b=, :validated, "File with mapping that is now validated", required: true
  on :i=, :intersection, "Intersection (conflicting taken from reference)"
  on :c=, :conflicts, "Conflicts category-wise"
  on :d=, :"reference-missing", "Missing entries in reference mapping"
  on :e=, :"validated-missing", "Missing entries in validated mapping"
  on :v, :verboese, "Print verboes results (useful for small mappings)"
  on :p=, :port, "Cyc port", as: Integer, default: 3601
  on :h=, :host, "Cyc host", default: 'localhost'
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

$verbose = !!options[:verbose]

def puts(*args)
  Kernel.puts(*args) if $verbose
end

def extract_file_name(name)
  name[name.rindex("/")+1..-1]
end

reference_name = extract_file_name(options[:reference])
validated_name = extract_file_name(options[:validated])
cyc = Cyc::Client.new(port: options[:port], host: options[:host], cache: true)
name_service = Mapping::Service::CycNameService.new(cyc)

mappings = []
cyc_names = {}
2.times do |index|
  mappings << Mapping::BidirectionalMap.new
  file = (index == 0 ? options[:reference] : options[:validated])
  CSV.open(file) do |input|
    input.with_progress do |category_name,cyc_id,cyc_name|
      mappings[index].add(cyc_id, category_name)
      cyc_names[cyc_id] = cyc_name
    end
  end
end

intersection_size = mappings[0].intersection_values(mappings[1]).size
if options[:intersection]
  CSV.open(options[:intersection],"w") do |output|
    mappings[0].intersection_values(mappings[1]).each do |category,cyc_ids|
      output << [category,*cyc_ids.zip(cyc_ids.map{|id| cyc_names[id]}).flatten(1)]
    end
  end
end

puts 'Conflicts Cyc ids-wise'
puts "| Cyc | #{reference_name} | #{validated_name} |"
puts '| --- | --- | --- |'
mappings[0].conflicts_keys(mappings[1]).each do |cyc_id, reference, validated|
  puts ["", cyc_names[cyc_id],reference.to_a.join(', '), validated.to_a.join(', '),"" ].join("|")
end
puts

puts 'Conflicts categories-wise'
puts "| Category | #{reference_name} | #{validated_name} |"
puts '| --- | --- | --- |'
output = CSV.open(options[:conflicts],"w") if options[:conflicts]
conflicts_size = 0
soft_conflicts_size = 0
mappings[0].conflicts_values(mappings[1]).each do |category, reference, validated|
  if options[:conflicts]
    output << [category,*reference.zip(reference.map{|id| cyc_names[id]}).flatten(1),
               *validated.zip(validated.map{|id| cyc_names[id]}).flatten(1)]
  end
  puts ["", category,reference.map{|id| cyc_names[id]}.join(', '), validated.map{|id| cyc_names[id]}.join(', '),"" ].join("|")
  conflicts_size += 1
  term_1 = name_service.find_by_id(reference.first)
  term_2 = name_service.find_by_id(validated.first)
  if !cyc.genls?(term_1,term_2) && !cyc.genls?(term_2,term_1)
    soft_conflicts_size += 1
  end
end
puts
output.close if options[:conflicts]

puts "Mappings not in #{validated_name}"
puts "| Categories | #{reference_name} |"
puts '| --- | --- |'
output = CSV.open(options[:"validated-missing"],"w") if options[:"validated-missing"]
mappings[0].difference_values(mappings[1]).each do |category, reference|
  output << [category,*reference.zip(reference.map{|id| cyc_names[id]}).flatten(1)] if options[:"validated-missing"]
  puts ["",category,reference.map{|id| cyc_names[id]}.join(', '),""].join("|")
end
puts
output.close if options[:"validated-missing"]

puts "Mappings not in #{reference_name}"
puts "| Categories | #{validated_name} |"
puts '| --- | --- |'
output = CSV.open(options[:"reference-missing"],"w") if options[:"reference-missing"]
mappings[1].difference_values(mappings[0]).each do |category, validated|
  output << [category,*validated.zip(validated.map{|id| cyc_names[id]}).flatten(1)] if options[:"reference-missing"]
  puts ["",category,validated.map{|id| cyc_names[id]}.join(', '),""].join("|")
end
puts
output.close if options[:"reference-missing"]

precision = (intersection_size - conflicts_size)/intersection_size.to_f * 100
soft_precision = (intersection_size - soft_conflicts_size)/intersection_size.to_f * 100
recall = (intersection_size - conflicts_size)/mappings[0].values_size.to_f * 100
f1 = (2 * precision * recall) / (precision + recall)
Kernel.puts("| %.1f%% | %.1f%% | %.1f%% | %.1f%% |" % [ precision,soft_precision,recall,f1])
