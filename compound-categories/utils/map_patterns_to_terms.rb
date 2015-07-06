#!/usr/bin/env ruby

require 'bundler/setup'
$:.unshift "lib"
require 'slop'
require 'progress'
require 'csv'
require 'rlp/wiki'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -d database -i patterns.csv -o mapping.csv [-m categories.csv] [-l limit] [-x offset] [-z support]\n"+
    "Map category name patterns to Cyc terms"

  on :d=, :database, "ROD database with Wikipedia data", required: true
  on :i=, :input, "File with categories grouped by matching patterns", required: true
  on :o=, :output, "Output file with patterns mapped to terms", required: true
#  on :s=, :services, "File with addresses of ROD-rest services"
  on :x=, :offset, "Pattern offset (skip first n patterns)", as: Integer, default: 0
  on :l=, :limit, "Pattern limit (limit processing to n patterns)", as: Integer
  on :c=, :count, "Maximum number of sample articles for each pattern", as: Integer, default: 1000
  on :z=, :support, "Minimum support for a pattern to be mapped", as: Integer, default: 10
  on :m=, :mapping, "Category mapping (alternative for DBpedia types)"
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

total_patterns_count = `wc -l #{options[:input]}`.to_i
limit = options[:limit] || total_patterns_count
patterns_count = [limit,total_patterns_count-options[:offset]].min
include Rlp::Wiki
Database.instance.open_database(options[:database])
at_exit do
  Database.instance.close_database
end

if options[:mapping]
  category_mapping = Hash.new{|h,e| h[e] = [] }
  CSV.open(options[:mapping],"r:utf-8") do |input|
    input.with_progress do |row|
      category_name = row.shift
      method_type = row.shift
      max_probability = nil
      row.each_slice(4) do |cyc_id,cyc_name,positive,total|
        probability = positive.to_f / total.to_f
        next if probability.nan?
        category_mapping[category_name] << [cyc_id,cyc_name,probability]
      end
    end
  end
  category_mapping.keys.each do |category_name|
    values = category_mapping[category_name]
    max_prob = values.sort_by{|_,_,prob| -prob }.first.last
    category_mapping[category_name] = values.select{|_,_,prob| prob > max_prob - 0.01 }
  end
end

CSV.open(options[:output],"w") do |output|
  CSV.open(options[:input],"r:utf-8") do |input|
    Progress.start(patterns_count)
    pattern_index = 0
    input.each do |row|
      break if pattern_index >= patterns_count
      pattern_index += 1
      Progress.step(1)
      begin
        pattern = row.shift
        pattern_support = row.shift.to_i
        break if pattern_support < options[:support]
        if category_mapping
          counts = Hash.new{|h,e| h[e] = [] }
          row.each do |category_id|
            category = Category.find_by_wiki_id(category_id.to_i)
            next unless category_mapping.has_key?(category.name)
            category_mapping[category.name].each do |cyc_id,cyc_name,probability|
              counts[[cyc_id,cyc_name]] << probability
            end
          end
          mapping = counts.map do |key,probabilities|
            #[key,1 - probabilities.map{|p| 1 - p }.inject(:*)]
            [key,probabilities.size]
          end.sort_by{|k,v| - v}.flatten
          output << [pattern,pattern_support,*mapping] if mapping.size > 0
        else
          categories = row.map do |category_id|
            Category.find_by_wiki_id(category_id.to_i)
          end
          examples_count = 0
          example_index = 0
          counts = Hash.new(0)
          while(examples_count < options[:count] && !categories.empty?) do
            to_remove = []
            categories.each.with_index do |category,category_index|
              break if examples_count >= options[:count]
              example = category.concepts[example_index]
              if example.nil?
                to_remove << category_index
                next
              end
              if example.dbpedia_type
                counts[example.dbpedia_type] += 1
                examples_count += 1
              end
            end
            to_remove.reverse.each{|i| categories.delete_at(i) }
            example_index += 1
          end
          output << [pattern,pattern_support,*counts.sort_by{|k,v| -v }.map{|k,v| [k.cyc_id,k.name,v]}.flatten]
        end
      rescue Interrupt
        break
      rescue Exception => ex
        puts ex
        puts ex.backtrace[0..5]
      end
    end
    Progress.stop
  end
end
