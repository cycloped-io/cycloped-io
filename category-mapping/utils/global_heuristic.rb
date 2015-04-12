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
require 'benchmark'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f mapping.csv -o results.csv\n" +
             'Phase 2 of global heuristic. Final global mapping.'

  on :f=, :mapping, 'File with results of automatic mapping using local heuristics with support values from phase 1', required: true
  on :o=, :output, 'Output file'
  on :h=, :host, 'Cyc host (localhost)'
  on :p=, :port, 'Cyc port (3601)', as: Integer
end

begin
  options.parse
rescue Exception
  puts options
  exit
end

include Rlp::Wiki


Database.instance.open_database(options[:database] || '../rlp/data/en-2013')

cyc = Cyc::Client.new(host: options[:host] || 'localhost', port: options[:port] || 3601, cache: true)
name_service = Mapping::Service::CycNameService.new(cyc)



def load_local_mapping(file)
  local_mapping = Hash.new

  mapping = Struct.new(:full_name, :cyc_terms)

  CSV.open(file, 'r:utf-8') do |input|
    Progress.start(input.stat.size, 'Load mapping')
    input.each do |row|
      Progress.set(input.pos)
      category_id = row.shift.to_i
      full_name = (row.shift == 'true')
      results = []
      row.each_slice(7) do |cyc_id, parents_count, children_count, instances_count, sum_parents_count, sum_children_count, sum_instances_count|
        results << [cyc_id, parents_count.to_i, children_count.to_i, instances_count.to_i, sum_parents_count.to_i, sum_children_count.to_i, sum_instances_count.to_i]
      end
      local_mapping[category_id] = mapping.new(full_name, results)
    end
    Progress.stop
  end


  return local_mapping
end



def find_roots
  roots = []
  if File.exists?('roots.marshall')
    File.open('roots.marshall') do |file|
      roots = Marshal.load(file).map { |id| Category.find_by_wiki_id(id) }
    end
  else
    Progress.start(Category.count, 'Find roots')
    Category.each do |category|
      Progress.step
      next unless category.regular?
      next unless category.plural?
      if category.semantic_parents.empty?
        roots.push category
      end
    end
    Progress.stop

    Marshal.dump(roots.map { |c| c.wiki_id }, File.open('roots.marshall', 'w'))
  end
  return roots
end

local_mapping = load_local_mapping(options[:mapping])
roots = find_roots

$visited = Set.new
$mapping = Hash.new

$statistics = Hash.new(0)

class MappedCycTerm
  attr_accessor :cyc, :support, :inherited, :description

  def initialize(cyc, support, inherited=false, description='')
    @cyc = cyc
    @support = support
    @inherited = inherited
    @description = description
  end
end

def assign(root, stats, cyc, name_service)
  queue = [root]
  while not queue.empty?
    category = queue.pop
    next if $visited.include? category
    $visited.add category

    proposition_struct = Struct.new(:cyc, :support, :semantic_parent_mappings, :invalid_semantic_parent_mappings)

    if stats.include?(category.wiki_id)
      propositions = []

      stats[category.wiki_id].cyc_terms.each do |entry|
        cyc_id, parents_count, children_count, instances_count, sum_parents_count, sum_children_count, sum_instances_count = entry
        sum = parents_count + children_count+ instances_count+ sum_parents_count+ sum_children_count+ sum_instances_count

        semantic_parent_mappings = 0
        invalid_semantic_parent_mappings = 0
        category.semantic_parents.each do |parent|
          next unless $mapping.has_key?(parent.wiki_id)

          begin
            if cyc.genls?(name_service.find_by_id(cyc_id), name_service.find_by_id($mapping[parent.wiki_id].cyc))

            elsif stats[category.wiki_id].full_name == false && cyc.genls?(name_service.find_by_id($mapping[parent.wiki_id].cyc), name_service.find_by_id(cyc_id))
              $statistics['child is generalization and is not full name'] += 1
              #TODO intersection
            else
              invalid_semantic_parent_mappings += 1
            end

            semantic_parent_mappings += 1
          rescue NoMethodError => ex
            p cyc_id, $mapping[parent.wiki_id].cyc
            STDERR.puts ex
            STDERR.puts ex.backtrace

          end
        end
        propositions.push proposition_struct.new(cyc_id, sum, semantic_parent_mappings, invalid_semantic_parent_mappings)
      end

      if propositions.size == 0
        $statistics['no propositions'] += 1
        if category.semantic_parents.empty?
          $statistics['no propositions and no semantic parents'] += 1
        else
          best = category.semantic_parents.select{|parent| $mapping.include?(parent.wiki_id)}.max_by{|parent| $mapping[parent.wiki_id].support}
          best = $mapping[best]
          $mapping[category.wiki_id] = MappedCycTerm.new(best.cyc, best.support, true, 'no candidates, but semantic parents') unless best.nil?
        end



      else

        valid_propositions = propositions.select { |proposition| proposition.semantic_parent_mappings > 0 && proposition.invalid_semantic_parent_mappings==0 }

        if valid_propositions.size == 1
          $mapping[category.wiki_id] = MappedCycTerm.new(valid_propositions.first.cyc, valid_propositions.first.support)



          if valid_propositions.first.support == 0
            $statistics['only one valid with support == 0'] += 1
            $mapping[category.wiki_id].description = 'only one valid with support == 0'
          else
            $statistics['only one valid with support > 0'] += 1
            $mapping[category.wiki_id].description = 'only one valid with support > 0'
          end

          if valid_propositions.first.support < propositions.max_by{|proposition| proposition.support}.support
            $statistics['only one valid but invalid with higher support'] += 1
            $mapping[category.wiki_id].description += ' but invalid with higher support'
          end

        elsif valid_propositions.size > 1
          best = valid_propositions.max_by { |proposition| proposition.support }

          if best.support < propositions.max_by{|proposition| proposition.support}.support
            $statistics['more than one valid but invalid with higher support'] += 1
          end

          if best.support == 0
            $statistics['more than one valid with support == 0'] += 1
            best = category.semantic_parents.select{|parent| $mapping.include?(parent.wiki_id)}.max_by{|parent| $mapping[parent.wiki_id].support}
            best = $mapping[best]
            $mapping[category.wiki_id] = MappedCycTerm.new(best.cyc, best.support, true, 'more than one valid with support == 0') unless best.nil?
          else
            $mapping[category.wiki_id] = MappedCycTerm.new(best.cyc, best.support, false, 'more than one valid with support > 0')
            $statistics['more than one valid with support > 0'] += 1
          end
        else
          root = propositions.all? { |proposition| proposition.semantic_parent_mappings == 0 }
          if root

            $statistics['root'] += 1
            best = propositions.max_by { |proposition| proposition.support }

            if best.support > 0
              $mapping[category.wiki_id] = MappedCycTerm.new(best.cyc, best.support, false, 'root with support > 0')
              $statistics['root with support > 0'] += 1
            elsif propositions.size == 1
              $mapping[category.wiki_id] = MappedCycTerm.new(propositions.first.cyc, propositions.first.support, false, 'root with support == 0 and one candidate')
              $statistics['root with support == 0 and one candidate'] += 1
            else
              $statistics['root with support == 0 and more than one candidate'] += 1

            end
          else


            valid_with_some_parent_propositions = propositions.select { |proposition| proposition.semantic_parent_mappings > 0 && proposition.invalid_semantic_parent_mappings<proposition.semantic_parent_mappings }
            if valid_with_some_parent_propositions.size > 0
              best = valid_with_some_parent_propositions.max_by { |proposition| proposition.support }
              if best.support == 0
                $statistics['valid with some of parents, with support == 0'] += 1
                #TODO only valid parents
                best = category.semantic_parents.select{|parent| $mapping.include?(parent.wiki_id)}.max_by{|parent| $mapping[parent.wiki_id].support}
                best = $mapping[best]
                $mapping[category.wiki_id] = MappedCycTerm.new(best.cyc, best.support, true, 'valid with some of parents, with support == 0') unless best.nil?
              else
                $statistics['valid with some of parents, with support > 0'] += 1
                $mapping[category.wiki_id] = MappedCycTerm.new(best.cyc, best.support, false, 'valid with some of parents, with support > 0')
              end

            else
              invalid_with_all_parents = propositions.select { |proposition| proposition.semantic_parent_mappings > 0 && proposition.invalid_semantic_parent_mappings==proposition.semantic_parent_mappings }
              if invalid_with_all_parents.size == propositions.size
                best = invalid_with_all_parents.max_by { |proposition| proposition.support }
                best_parent = category.semantic_parents.select{|parent| $mapping.include?(parent.wiki_id)}.max_by{|parent| $mapping[parent.wiki_id].support}
                best_parent = $mapping[best_parent]
                $mapping[category.wiki_id] = MappedCycTerm.new(best_parent.cyc, best_parent.support, true) unless best_parent.nil?
                if best.support == 0
                  $statistics['all invalid with all parents, with support == 0'] += 1
                  $mapping[category.wiki_id].description = 'all invalid with all parents, with support == 0' unless best_parent.nil?
                else
                  $statistics['all invalid with all parents, with support > 0'] += 1
                  $mapping[category.wiki_id].description = 'all invalid with all parents, with support > 0' unless best_parent.nil?
                end
              end
            end
          end
        end
      end

    else
      semantic_parents = category.semantic_parents
      if semantic_parents.size == 0
        $statistics['without Cyc proposition, without parent'] += 1
      elsif semantic_parents.size == 1
        $statistics['without Cyc proposition, with one parent'] += 1
        parent_id = semantic_parents.first.wiki_id
        if $mapping.include? parent_id
          if $mapping[parent_id].support > 0
            $statistics['without Cyc proposition, with one Cyc parent with support > 0'] += 1
          else
            $statistics['without Cyc proposition, with one Cyc parent with support == 0'] += 1
          end
          $mapping[category.wiki_id] = MappedCycTerm.new($mapping[parent_id].cyc, $mapping[parent_id].support, true, 'without Cyc proposition, with one Cyc parent')
        else
          $statistics['without Cyc proposition, with one parent without Cyc mapping'] += 1
        end

      else
        $statistics['without Cyc proposition, with more than one parent'] += 1
        best_parent = semantic_parents.select{|parent| $mapping.include?(parent.wiki_id)}.max_by { |parent| $mapping[parent.wiki_id].support }

        if best_parent && ($mapping.include? best_parent.wiki_id)
          parent_id = best_parent.wiki_id
          if $mapping[parent_id].support > 0
            $statistics['without Cyc proposition, with more than one parent with support > 0'] += 1
            $mapping[category.wiki_id] = MappedCycTerm.new($mapping[parent_id].cyc, $mapping[parent_id].support, true, 'without Cyc proposition, with more than one parent with support > 0')
          else
            $statistics['without Cyc proposition, with more than one parent with support == 0'] += 1
          end
        else
          $statistics['without Cyc proposition, with more than one parent without Cyc mapping'] += 1
        end
      end
    end

    category.get_semantic_children.each do |child|
      queue.unshift child
    end

  end


end

roots.with_progress do |root|
  assign(root, local_mapping, cyc, name_service)
end



p $statistics


phase2 = CSV.open('global_mapping_phase2.csv', 'w')
$mapping.each do |k, v|
  phase2 << [k, v.cyc, v.support, v.inherited, v.description]
end
phase2.close


# LAST RUN

# 100.0% (elapsed: 32.7m)
#{"root"=>64831,
# "root with support > 0"=>5991,
# "child is generalization and is not full name"=>12906,
# "only one valid with support > 0"=>117057,
# "only one valid with support == 0"=>261101,
# "no propositions"=>42026,
# "all invalid with all parents, with support == 0"=>27445,
# "root with support == 0 and more than one candidate"=>31798,
# "root with support == 0 and one candidate"=>27042,
# "only one valid but invalid with higher support"=>5893,
# "all invalid with all parents, with support > 0"=>3863,
# "no propositions and no semantic parents"=>8945,
# "without Cyc proposition, with more than one parent"=>15,
# "without Cyc proposition, with more than one parent with support > 0"=>10,
# "valid with some of parents, with support == 0"=>3515,
# "more than one valid with support == 0"=>595,
# "more than one valid with support > 0"=>1022,
# "valid with some of parents, with support > 0"=>2831,
# "without Cyc proposition, with one parent"=>103,
# "without Cyc proposition, with one parent without Cyc mapping"=>18,
# "without Cyc proposition, with one Cyc parent with support > 0"=>11,
# "more than one valid but invalid with higher support"=>6,
# "without Cyc proposition, with more than one parent with support == 0"=>3,
# "without Cyc proposition, with one Cyc parent with support == 0"=>74,
# "without Cyc proposition, with more than one parent without Cyc mapping"=>2}