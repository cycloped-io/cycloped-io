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
    "Assign Cyc high-level concepts (determined empirically) to the etities"

  on :f=, :input, "File with entities classification", required: true
  on :o=, :output, "File with classification to high-level concepts", required: true
  on :t=, :types, "Cyc high-level concepts", required: true
  on :F=, :fields, "Number of header fields in each row", default: 1, as: Integer
  on :h=, :host, "Cyc host", default: "localhost"
  on :p=, :port, "Cyc port", as: Integer, default: 3601
  on :m=, :method, "Assignement method: g - genls (default), i - isa"
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

def convert_array_to_cyc(array)
  -> { "'(" + array.map{|e| e.to_cyc(true) }.join(" ") + ')' }
end

cyc = Cyc::Client.new(cache: true, host: options[:host], port: options[:port])
#cyc.debug = true
name_service = Mapping::Service::CycNameService.new(cyc)

types = []
CSV.open(options[:types]) do |input|
  input.with_progress do |row|
    types << name_service.find_by_term_name(row.first)
    if types.last.nil?
      puts row.first
    end
  end
end

thing_term = name_service.find_by_term_name("Thing")

types = convert_array_to_cyc(types.compact)

CSV.open(options[:input]) do |input|
  CSV.open(options[:output],"w") do |output|
    input.with_progress do |row|
      header = row.shift(options[:fields])
      cyc_id,cyc_name = row
      if header.empty?
        header = [cyc_id,cyc_name]
      end
      begin
        term = name_service.find_by_id(cyc_id)
        if options[:method] == 'i'
          parents = cyc.with_any_mt{|c| c.all_isa_among(term,types)}
        else
          parents = cyc.with_any_mt{|c| c.all_genls_among(term,types)}
        end
        next if parents.nil? || parents.empty?
        tuple = [*header]
        cyc.with_any_mt{|c| c.min_cols(convert_array_to_cyc(parents)) }.each do |term|
          id = cyc.compact_hl_external_id_string(term)
          # output << header + [id,term]
          tuple << id << term
        end
      rescue Interrupt
        break
      rescue => ex
        puts ex
        puts ex.backtrace[0..5]
        puts "#{header.join(" ")} #{cyc_id} #{cyc_name}"
        tuple << thing_term.id << thing_term.to_ruby.to_s
      end
      output << tuple
    end
  end
end
