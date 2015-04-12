#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
require 'colors'
require 'progress'
require 'csv'
require 'slop'
$:.unshift "../category-mapping/lib"
$:.unshift "lib"
require 'mapping/cyc_term'
require 'mapping/service/cyc_name_service'
require 'resolver/graph_factory'
require 'resolver/graph_walker'
require 'resolver/divider'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f classification.csv -o resolution.csv -d db [...]\n"
    "Resolve conflicts between different Wikipedia article type assignemnts"

  on :f=, :input, "Input file with type assginments", required: true
  on :o=, :output, "Output file with resolved conflicts", required: true
  on :h=, :host, "Cyc host", default: "localhost"
  on :p=, :port, "Cyc port", as: Integer, default: 3601
  on :v, :verbose, "Verbose mode"
  on :x=, :offset, "Index of the first entry to process", as: Integer, default: 0
  on :l=, :limit, "Number of entries to process", as: Integer, default: -1
  on :b=, :blacklist, "Path to file with blacklisted concepts"
  on :F=, :fields, "Number of header fields in each row", as: Integer, default: 1
  on :m=, :mode, "Mapping description mode: r - repeadte mappings, a - aggregated counts, p - probabilities", default: "r"
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end


debug = options[:verbose]

total = `wc -l #{options[:input]}`.to_i
start_index = options[:offset]
if options[:limit] > 0
  end_index = options[:offset] + options[:limit]
else
  end_index = total
end

if options[:blacklist]
  blacklist = File.readlines(options[:blacklist]).map(&:chomp).map(&:to_sym)
else
  blacklist = []
end

cyc = Cyc::Client.new(cache: true, host: options[:host], port: options[:port])
name_service = Mapping::Service::CycNameService.new(cyc)

puts "Started"
individual_count = 0
collection_count = 0

graph_factory = Resolver::GraphFactory.new do |term1,term2|
  if cyc.genls?(term1,term2)
    -1
  elsif cyc.genls?(term2,term1)
    1
  else
    0
  end
end

divider = Resolver::Divider.new do |term1,term2|
  cyc.collections_disjoint?(term1,term2)
end

terms_support = Hash.new(0)
term_probability = Hash.new{|h,e| h[e] = [] }
support_computer = Resolver::GraphWalker.new do |sum,node|
  sum + terms_support[node.value]
end
probability_computer = Resolver::GraphWalker.new do |product,node|
  product * term_probability[node.value].inject(1){|p,v| p * (1-v)}
end
ancestor_founder = Resolver::GraphWalker.new do |ancestors,node|
  ancestors << node.value
end

Progress.start(end_index - start_index) unless debug
CSV.open(options[:output],"w") do |output|
  CSV.open(options[:input],"r:utf-8") do |input|
    input.each_with_index do |row,index|
      next if index < start_index
      break if index > end_index
      begin
        Progress.step(1) unless debug
        terms_support.clear
        term_probability.clear
        header = row.shift(options[:fields])
        terms = row
        if debug
          puts "=== #{header.join(",")} ===".hl(:blue)
        end
        result = header
        case options[:mode]
        when "r" # repeated mappings
          terms.each_slice(2) do |term_id,term_name|
            term = name_service.find_by_id(term_id)
            next if cyc.isa?(term,:Individual)
            terms_support[term] += 1
          end
        when "p" # probabilities
          terms.each_slice(3) do |term_id,term_name,probability|
            term = name_service.find_by_id(term_id)
            next if cyc.isa?(term,:Individual)
            terms_support[term] += 1
            term_probability[term] << probability.to_f
          end
        when "a" # aggregated counts
          terms.each_slice(3) do |term_id,term_name,support|
            term = name_service.find_by_id(term_id)
            next if cyc.isa?(term,:Individual)
            terms_support[term] = support.to_f
          end
        else
          puts "Invalid mode: #{options[:mode]}"
          break
        end
        if debug
          puts "Terms to resolve: #{terms_support.keys.map{|t| t.name }.join(",")}"
        end

        graph = graph_factory.create(terms_support.keys)
        partitions = divider.partitions(graph)
        histogram = Hash.new(0)
        if options[:mode] == "p"
          partitions.each do |partition|
            histogram[partition] = (1-probability_computer.apply(partition,:parents,1)).round(5)
          end
        else
          partitions.each do |partition|
            histogram[partition] += support_computer.apply(partition,:parents,0)
          end
        end
        histogram.sort_by{|_,s| -s }.each do |partition,support|
          print "- #{support}: " if debug
          result << "P" << support
          ancestor_founder.apply(partition,:parents,[]).each do |term|
            print "#{term.to_ruby}:#{terms_support[term]} " if debug
            result << term.id << term.to_ruby.to_s << terms_support[term]
          end
          puts if debug
        end
        output << result
      rescue Interrupt
        puts
        break
      rescue Exception => ex
        puts ex
        puts ex.backtrace[0..5]
      end
    end
  end
end
Progress.stop unless debug
