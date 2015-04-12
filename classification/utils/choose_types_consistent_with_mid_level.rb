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
             ""

  on :i=, :input, "File with entities classification", required: true
  on :o=, :output, "File with classification consistent with mid-level", required: true
  on :m=, :midlevel, "Mid-level classification", required: true
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

mid_level = {}
CSV.open(options[:midlevel]) do |input|
  input.with_progress do |wiki_name, *cycs|
    types = []
    cycs.each_slice(2) do |cyc_id,cyc_name|
      types << cyc_id
    end
    mid_level[wiki_name] = types
  end
end

CSV.open(options[:input]) do |input|
  CSV.open(options[:output],"w") do |output|
    input.with_progress do |wiki_name, *cycs|
      next if !mid_level.include?(wiki_name)
      types = Hash.new(0.0)      #TODO set
      cycs.each_slice(3) do |cyc_id,cyc_name,probability|
        if  mid_level[wiki_name].any{|type| cyc.with_any_mt{|c| c.genls?(name_service.find_by_id(cyc_id), name_service.find_by_id(type))}}
          types[[cyc_id,cyc_name]] = max(types[[cyc_id,cyc_name]],probability)
        end
      end
      output << [wiki_name]+ types.map{|k,v| [k]+v}.flatten
    end
  end
end