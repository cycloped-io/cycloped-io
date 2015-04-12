#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
require 'slop'
require 'csv'
require 'colors'
require 'active_model/naming'
require 'progress'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -i articles_in_categories.csv -o eponymous_categries.csv -d database\n" +
    "Export eponymous categories from article names found in category names."

  on :i=, :input, "Input file (CSV)", required: true
  on :o=, :output, "Output file with eponymous categories (CSV)", required: true
  on :d=, :database, "ROD database", required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

include Rlp::Wiki
Database.instance.open_database(options[:database])

potential_count = 0
exported_count = 0
Progress.start(`wc -l #{options[:input]}`.to_i)
CSV.open(options[:output],"w:utf-8") do |output|
  CSV.open(options[:input],"r:utf-8") do |input|
    input.each do |row|
      Progress.step(1)
      begin
        category_id,category_name,*tuples = row
        tuples.each_slice(3) do |prefix,concept_name,suffix|
          next unless prefix.empty? && suffix.empty?
          category = Category.find_by_wiki_id(category_id.to_i)
          concept = Concept.find_all_by_name(concept_name).to_a.compact.first
          next unless category.eponymous_concepts.empty?
          next if category.nil? || concept.nil?
          potential_count += 1
          #intersection = category.parents.to_a & concept.categories.to_a
          intersection = []
          if category_name == concept_name
            output << [category_id,category_name,concept.wiki_id,concept_name]
            exported_count += 1
            next
            #category_name = category_name.hl(:purple)
            #concept_name = concept_name.hl(:purple)
          elsif category_name.match(/#{Regexp.escape(concept_name)}/i)
            if $`.empty? && category_name.singularize == concept_name
              output << [category_id,category_name,concept.wiki_id,concept_name]
              exported_count += 1
              next
            end
            #category_name = $`.hl(:yellow) + concept_name + $'.hl(:green)
          elsif concept_name.match(/#{Regexp.escape(category_name)}/i)
            if $'.empty?
              output << [category_id,category_name,concept.wiki_id,concept_name]
              exported_count += 1
              next
            end
            #concept_name = $`.hl(:yellow) + category_name + $'.hl(:blue)
          else
            first_index = category_name.split("").zip(concept_name.split("")).each.with_index do |(category_char,concept_char),index|
              break(index) if category_char != concept_char
            end
            if first_index && first_index > 0
              if category_name =~ /people$/
                output << [category_id,category_name,concept.wiki_id,concept_name]
                exported_count += 1
                next
              elsif category_name.singularize == concept_name
                output << [category_id,category_name,concept.wiki_id,concept_name]
                exported_count += 1
                next
              elsif concept_name[0...first_index].pluralize + concept_name[first_index..-1] == category_name
                output << [category_id,category_name,concept.wiki_id,concept_name]
                exported_count += 1
                next
              end
              #category_name = category_name[0...first_index] + category_name[first_index..-1].hl(:green)
              #concept_name = concept_name[0...first_index] + concept_name[first_index..-1].hl(:blue)
            end
          end

          #puts "#{category_name},#{concept_name},#{intersection.size}"
        end
      rescue Interrupt
        puts
        break
      rescue Exception => ex
        puts row.join(",").hl(:red)
        puts ex
        puts ex.backtrace[0..3]
      end
    end
  end
end
puts "#{exported_count}/#{potential_count}"
Progress.stop
Database.instance.close_database
