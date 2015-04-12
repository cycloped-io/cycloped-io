#!/usr/bin/env ruby

require 'bundler/setup'
require 'rlp/wiki'
$:.unshift 'lib'
require 'slop'
require 'csv'
require 'cycr'
require 'progress'
require 'colors'

require 'mapping/cyc_term'
require 'mapping/service/cyc_name_service'
require 'mapping/bidirectional_map'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -f mapping.csv -d database [-h host] [-p port] [-v]\n" +
    "Detect conflicts between mappings and semantic parents/children"

  on :f=, :input, "File with mapping", required: true
  on :h=, :host, 'Cyc host (localhost)', default: 'localhost'
  on :p=, :port, 'Cyc port (3601)', as: Integer, default: 3601
  on :d=, :database, 'ROD database', default:  '../rlp/data/en-2013'
  on :v, :verbose, 'Print verbose results', default: false
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end


cyc = Cyc::Client.new(host: options[:host], port: options[:port], cache: true)
name_service = Mapping::Service::CycNameService.new(cyc)
include Rlp::Wiki
Database.instance.open_database(options[:database])

mappings = {}
index = 0
CSV.open(options[:input],'r:utf-8') do |input|
  input.with_progress do |category_name,cyc_id,cyc_name|
    category = Category.find_by_name(category_name)
    if category.nil?
      puts "missing: #{category_name}"
      next
    end
    mappings[category] = name_service.find_by_id(cyc_id)
    index += 1
  end
end

categories_with_conflicts = 0
total_categories = 0
relations_with_conflicts = 0
total_relations = 0
#mappings.each.with_progress do |category,term|
Progress.start(mappings.size) unless options[:verbose]
mappings.each do |category,term|
  Progress.step(1) unless options[:verbose]
  total_categories += 1
  relations = []
  conflicts_count = 0
  local_relations = 0
  [:semantic_parents,:semantic_children].each do |relation|
    category.send(relation).each do |related_category|
      related_term = mappings[related_category]
      next if related_term.nil?
      local_relations += 1
      if cyc.collections_disjoint?(term,related_term)
        relations << [:"#{relation}_disjoint",related_category,related_term]
        conflicts_count += 1
      elsif !cyc.with_any_mt{|c| c.genls?(term,related_term) } && !cyc.with_any_mt{|c| c.genls?(related_term,term) }
        relations << [:"#{relation}_genls",related_category,related_term]
        conflicts_count += 1
      else
        relations << [:"#{relation}_valid",related_category,related_term]
      end
    end
  end
  total_relations += local_relations
  relations_with_conflicts += conflicts_count
  categories_with_conflicts += 1 if local_relations == conflicts_count && conflicts_count > 0
  if conflicts_count > 0 && options[:verbose]
    puts category.name.hl(:blue)
    puts "mapped to #{term.to_ruby}"
    relations.sort_by{|type,_,_| type }.each do |type,related_category,related_term|
      color =
        case type
        when :semantic_parents_valid,:semantic_children_valid
          :green
        when :semantic_parents_genls,:semantic_children_genls
          :yellow
        else
          :red
        end
      type = (type.to_s =~ /parent/ ? "parent" : "child")
      puts "- #{type}: #{related_category.name.hl(color)} #{related_term.to_ruby}"
    end
  end
end
Progress.stop unless options[:verbose]
puts "Categories: #{categories_with_conflicts}/#{total_categories}/%.1f%%" % [categories_with_conflicts/total_categories.to_f*100]
puts "Relations: #{relations_with_conflicts}/#{total_relations}/%.1f%%" % [relations_with_conflicts/total_relations.to_f*100]
puts "Relations per category: %.2f/%.2f" % [relations_with_conflicts/categories_with_conflicts.to_f,total_relations/total_categories.to_f]
Database.instance.close_database
