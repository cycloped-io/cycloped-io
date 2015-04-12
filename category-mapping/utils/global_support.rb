#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
$:.unshift 'lib'
require 'slop'
require 'csv'
require 'cycr'
require 'progress'
require 'mapping/service/cyc_name_service'
require 'mapping/cyc_term'
require 'mapping/candidate'
require 'benchmark'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f local_mapping.csv -o phase1.csv\n" +
             'Phase 1 of global heuristic. Support values are propagated up in category hierarchy.'

  on :f=, :mapping, 'File with results of automatic mapping using local heuristics', required: true
  on :o=, :output, 'Output file', required: true
  on :d=, :database, 'ROD database', required: true
  on :c=, :"category-dump", 'Dumped category tree', default: 'queue2.marshall'
  on :h=, :host, 'Cyc host (localhost)', default: 'localhost'
  on :p=, :port, 'Cyc port (3601)', as: Integer, default: 3601
end

begin
  options.parse
rescue Exception => ex
  puts ex
  puts options
  exit
end

include Rlp::Wiki
Database.instance.open_database(options[:database])

cyc = Cyc::Client.new(host: options[:host], port: options[:port], cache: true)
name_service = Mapping::Service::CycNameService.new(cyc)

MappingStruct = Struct.new(:full_name, :cyc_terms)

def load_local_mapping(file, service)
  local_mapping = Hash.new
  CSV.open(file, 'r:utf-8') do |input|
    input.with_progress do |row|
      category_id = row.shift.to_i
      full_name = (row.shift == 'true')
      stats = []
      row.each_slice(4) do |cyc_id, parents_count, children_count, instances_count|
        stats << Mapping::Candidate.new(cyc_id, parents_count.to_i, children_count.to_i, instances_count.to_i,service)
      end
      local_mapping[category_id] = MappingStruct.new(full_name, stats)
    end
  end
  local_mapping
end


def load_sorted_categories(category_dump_path)
  visited = Set.new
  list = []

  dfs = ->(node) do
    unless visited.include? node
      node.semantic_children.each do |child|
        unless visited.include? child
          dfs.call(child)
        end
      end
      visited.add node
      list.unshift node
    end
  end

  queue = nil

  if File.exists?(category_dump_path)
    File.open(category_dump_path) do |file|
      queue = Marshal.load(file).map { |id| Category.find_by_wiki_id(id) }
    end
  else
    Progress.start(Category.count, 'Topological sorting')
    count_categories = 0
    Category.each do |category|
      Progress.step
      next unless category.regular?
      next unless category.plural?
      count_categories += 1
      if category.semantic_parents.empty?
        dfs.call(category)
      end
    end
    Progress.stop
    puts count_categories

    list.reverse!
    queue=list

    File.open(category_dump_path, 'w') do |output|
      Marshal.dump(list.map { |c| c.wiki_id }, output)
    end
  end
  queue
end

stats = load_local_mapping(options[:mapping], name_service)
queue = load_sorted_categories(options[:'category-dump'])

visited=Set.new
queue.with_progress do |category|
  visited.add(category)
  next unless stats.include?(category.wiki_id)
  next if category.semantic_children.empty?
  stats[category.wiki_id].cyc_terms.each do |candidate_entry|
    category.semantic_children.each do |child|
      if not visited.include?(child)
        puts 'error', child
      end
      next unless stats.include?(child.wiki_id)
      max_count = 0
      max_entry = nil

      # TODO sort by sum and break if found
      stats[child.wiki_id].cyc_terms.each do |child_entry|
        begin
          if cyc.genls?(child_entry.cyc_term, candidate_entry.cyc_term) or cyc.genls?(candidate_entry.cyc_term, child_entry.cyc_term)
            if child_entry.total_count > max_count
              max_count = child_entry.total_count
              max_entry = child_entry
            end
          end
        rescue NoMethodError => ex
          puts category.name
          puts ex
          puts ex.backtrace[0..5]
        end
      end
      if max_entry
        candidate_entry.parents_count += max_entry.parents_count
        candidate_entry.children_count += max_entry.children_count
        candidate_entry.instances_count += max_entry.instances_count
      end
    end
  end
end


CSV.open(options[:output], 'w') do |output|
  stats.each do |category_id, struct|
    output << [category_id, struct.full_name, *struct.cyc_terms.map(&:to_a).map { |e| e[0..3] }.flatten]
  end
end

Database.instance.close_database

# LAST RUN

#Load mapping: 100.0% (elapsed: 36s)
#100.0% (elapsed: 45.0m)
