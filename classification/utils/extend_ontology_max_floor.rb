#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'progress'
require 'csv'
require 'slop'
require 'cycr'
require 'set'
$:.unshift "../category-mapping/lib"
require 'mapping/cyc_term'
require 'mapping/service/cyc_name_service'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f collections.csv -o extension.csv -t terms.csv\n"
  "Extend the ontology with minimal specialization of collections"

  on :f=, :input, "Input file with initial ontology", required: true
  on :o=, :output, "Output file with extended ontology", required: true
  on :t=, :types, "Cyc high-level concepts", required: true
  on :u=, :unique, "Cyc high-level concepts unique", required: true
  on :h=, :host, "Cyc host", default: "localhost"
  on :p=, :port, "Cyc port", as: Integer, default: 3601
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end


cyc = Cyc::Client.new(cache: true, host: options[:host], port: options[:port])
name_service = Mapping::Service::CycNameService.new(cyc)


def convert_array_to_cyc(array)
  -> { "'(" + array.map { |e| e.to_cyc(true) }.join(" ") + ')' }
end

types = []
CSV.open(options[:types]) do |input|
  input.each do |row|
    types << name_service.find_by_term_name(row.first)
  end
end
types.compact!
types.map!{|e| e.to_ruby }
types = Set.new(types)
#types = convert_array_to_cyc(types)

unique_added = Hash.new(0)

CSV.open(options[:output], "w") do |output|
  CSV.open(options[:input]) do |input|
    input.with_progress do |cyc_id, name, count|
      #next if count.to_i <= 2
      begin
        term = name_service.find_by_id(cyc_id)
        assigned_types = cyc.with_any_mt{|c| c.all_genls(term) }
        if assigned_types.nil?
          puts "Missing generalization: #{name}"
          next
        end
        assigned_types = (Set.new(assigned_types) & types).to_a
        steps = 0
        while assigned_types.size>1 && steps<30 do
          steps+=1
          floor_cols = cyc.with_any_mt { |c| c.max_floor_cols(convert_array_to_cyc(assigned_types)) }
          assigned_types = floor_cols.select { |col| cyc.with_any_mt { |c| c.genls?(term, col) } }
        end

        tuple = [cyc_id, name, count]
        assigned_types.each do |term|
          id = cyc.compact_hl_external_id_string(term)
          tuple << id << term
          unique_added[term] += 1
        end
        output << tuple
      rescue Interrupt
        break
      rescue => ex
        #puts ex
        #puts ex.backtrace[0..5]
        puts "Error for: #{name} #{cyc_id} #{count}"
      end
    end
  end
end


p 'Unique added types: ', unique_added.size

CSV.open(options[:unique], "w") do |unique|
  unique_added.each do |term,count|
    unique << [term, count]
  end
end
