#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
$:.unshift "lib"
require 'slop'
require 'csv'
require 'progress'
require 'colors'
require 'mapping'
require 'mapping/candidate'
require 'mapping/service/disambiguation'
require 'set'
require 'rlp/wiki'

include Rlp::Wiki

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f mapping.csv -d database [-h host] [-p port]\n" +
    "Provide types for not disambiguated categories by inheriting from parent categories"

  on :f=, :mapping, "File with results of automatic mapping with computed local support", required: true
  on :d=, :database, "Rod database path", required: true
  on :p=, :port, "Cyc port", as: Integer, default: 3601
  on :h=, :host, "Cyc host", default: 'localhost'
  on :x=, :offset, "Category offset", as: Integer, default: 0
  on :c=, :count, "Number of categories to fix (includes good ones)", as: Integer
  on :o=, :output, "Output file with disambiguation", required: true
  on :l=, :list, "List of category names to disambiguate"
  on :v, :verbose, "Verbose output"
end

begin
  options.parse
rescue Exception => ex
  puts ex
  puts options
  exit
end


cyc = Cyc::Client.new(port: options[:port], host: options[:host], cache: true)
name_service = Mapping::Service::CycNameService.new(cyc)
Database.instance.open_database(options[:database])

if options[:list]
  list_of_categories = Hash[File.readlines(options[:list]).map(&:chomp).map{|c| [c,false]}]
end

category_mapping = Hash.new{|h,e| h[e] = [] }
# assume concepts with 0 signals, have the mean probability of concepts with 1
# signal
one_evidence_positive_count = 0
one_evidence_negative_count = 0
CSV.open(options[:mapping],"r:utf-8") do |input|
  input.with_progress do |row|
    #break if category_mapping.size > 100000
    category_name = row.shift
    mapped_string = row.shift
    row.each_slice(4) do |tuple|
      candidate = Mapping::Candidate.new(*tuple)
      category_mapping[category_name] << candidate
      if candidate.total == 1
        if candidate.positive == 1
          one_evidence_positive_count += 1
        else
          one_evidence_negative_count += 1
        end
      end
    end
  end
end

mean = one_evidence_positive_count / (one_evidence_positive_count + one_evidence_negative_count).to_f
index = 0
Progress.start(category_mapping.size) unless options[:verbose]
CSV.open(options[:output],"w") do |output|
  service = Mapping::Service::Disambiguation.new(category_mapping,output,options[:verbose],name_service)
  category_mapping.keys.each.with_index do |(category_name),index|
    Progress.step(1) unless options[:verbose]
    begin
      next if index < options[:offset]
      break if options[:count] && options[:count] < index - options[:offset]
      if options[:list]
        next unless list_of_categories.has_key?(category_name)
      end
      mapping = category_mapping[category_name]
      # original mapping object has to stay intact
      next if mapping.inject(0){|s,c| s + c.positive } > 0
      mapping = service.recursive_disambiguation(category_name)
      if mapping.inject(0){|s,c| s + c.total } == 0 && mapping.size == 1
        candidate = mapping.first
        output_tuple = [category_name,"_PLUS_ONE_"]
        output_tuple.concat([candidate.cyc_id,candidate.cyc_name,mean.round(5),1])
        output << output_tuple
        if options[:verbose]
          puts category_name.hl(:purple) if options[:verbose]
          puts "* #{candidate.cyc_name.hl(:yellow)} : #{output_tuple[-2].round(5)}"
        end
      end
    rescue Interrupt => ex
      break
    #rescue Exception => ex
      puts ex
      puts ex.backtrace[0..5]
    end
  end
end
Progress.stop unless options[:verbose]
Database.instance.close_database
