#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
$:.unshift "lib"
$:.unshift "../category-mapping/lib/"
require 'colors'
require 'progress'
require 'csv'
require 'slop'
require 'cycr'
require 'set'
require 'resolver/reader'
require 'mapping/cyc_term'
require 'mapping/service/cyc_name_service'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f classification.csv -o resolution.csv -d db [...]\n"
    "Finds centroid term within set of non-conflicting classifications"

  on :i=, :input, "File with partitions", required: true
  on :o=, :output, "Output file with centroids", required: true
  on :g=, :graph, "Output file with graphical representation of last processed graph"
  on :x=, :offset, "Offset of first entry to process", default: 0, as: Integer
  on :l=, :limit, "Number of entries to process", as: Integer
  on :h=, :host, "Cyc host", default: "localhost"
  on :p=, :port, "Cyc port", as: Integer, default: 3601
  on :w=, :weight, "Weight of intermediate graph nodes", default: 0.5, as: Float
  on :F=, :fields, "Number of head fields in the input", default: 1, as: Integer
  on :v, :verbose, "Verbose output"
  on :s=, :selected, "Print debug information for the selected partition", as: Integer
  on :r, :remove, "Remove immediate terms from the graph"
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

def find_ceiling(terms,cyc)
  as_list = -> { "'(" + terms.map{|t| t.to_cyc(true) }.join(' ') + ')' }
  cyc.min_ceiling_cols(as_list)
end

def select_highest_support(partition,second_order_partition)
  centroid = partition.each.to_a.sort_by{|_,s| -s }.first.first
  partition.each do |term,support|
    second_order_partition[centroid.to_ruby][term.id] = support
  end
end

cyc = Cyc::Client.new(cache: true, host: options[:host], port: options[:port])
name_service = Mapping::Service::CycNameService.new(cyc)
reader = Resolver::Reader.new(name_service)
total_count = `wc -l #{options[:input]}`.to_i
count = total_count - options[:offset]
if options[:limit]
  count = [options[:limit],count].min
end

CSV.open(options[:output],"w") do |output|
  CSV.open(options[:input],"r:utf-8") do |input|
    Progress.start(count) unless options[:verbose]
    input.each.with_index do |row,index|
      begin
        Progress.step(1) unless options[:verbose]
        next if index < options[:offset]
        break if index >= options[:offset] + count
        head, partitions = reader.extract_partitions(row,options[:fields])
        puts "#{head.join(", ")}".hl(:blue) if options[:verbose]
        second_order_partition = Hash.new{|h,e| h[e] = {} }
        outliers = Hash.new(0)
        partitions.each.with_index do |partition,partition_index|
          begin
            if options[:verbose]
              puts "#{partition_index}. Partition (#{partition.support}):".hl(:yellow)
              partition.each do |term,support|
                puts "- #{term.to_ruby.to_s} #{support}"
              end
            end
            terms = []
            term_ids = Hash.new(options[:weight])
            partition.each do |term,support|
              minimal_generalizations = cyc.min_genls(term)
              next if minimal_generalizations.nil? || minimal_generalizations.include?(:Thing)
              terms << term
              term_ids[term.id] = support
            end
            compatibility_matrix = Hash.new{|h,e| h[e] = {} }
            ceiling = nil
            loop do
              ceiling = find_ceiling(terms,cyc)
              break if ceiling || terms.empty?
              outliers.clear
              terms.each.with_index do |term1,index|
                break if index + 1 == terms.size
                term2 = terms[index+1]
                if find_ceiling([term1,term2],cyc).nil?
                  terms.each do |term3|
                    next if term3 == term1 || term3 == term2
                    outliers[term1] += (find_ceiling([term1,term3],cyc).nil? ? 1 : 0)
                    outliers[term2] += (find_ceiling([term2,term3],cyc).nil? ? 1 : 0)
                    break if outliers[term1] != outliers[term2]
                  end
                  terms_to_remove =
                    if outliers[term1] > outliers[term2]
                      [term1]
                    elsif outliers[term1] < outliers[term2]
                      [term2]
                    else
                      [term1,term2]
                    end
                  puts "Removed: #{terms_to_remove}" if options[:verbose]
                  terms_to_remove.each{|t| terms.delete(t) }
                end
              end
            end
            if ceiling.nil? || ceiling.include?(:Thing)
              select_highest_support(partition,second_order_partition)
              next
            end
            if ceiling.size > 1
              new_ceiling = find_ceiling(ceiling,cyc)
              if new_ceiling
                ceiling = new_ceiling.dup
              end
            end
            as_list = -> { "'(" + terms.map{|t| t.to_cyc(true) }.join(' ') + ')' }
            queue = cyc.min_cols(as_list).dup
            parents = {}
            children = Hash.new{|h,e| h[e] = [] }
            visited = Set.new
            while(!queue.empty?) do
              term = queue.shift
              next if visited.include?(term)
              visited << term
              next if ceiling.include?(term)
              minimal_generalizations = cyc.min_genls(term)
              next if minimal_generalizations.nil?
              parents[term] = minimal_generalizations.dup
              parents[term].each do |parent|
                children[parent] << term
              end
              next if parents[term].any?{|t| ceiling.include?(t) }
              parents[term].reject{|t| visited.include?(t)  }.each{|t| queue.push(t) }
            end
            visited = Set.new
            queue = ceiling.dup
            while(!queue.empty?) do
              term = queue.shift
              next if visited.include?(term)
              visited << term
              children[term].reject{|t| visited.include?(t) }.each{|t| queue.push(t) }
            end
            # some elements of ceiling might not be reachable
            reachable = Set.new
            parents.each do |child,direct_parents|
              direct_parents.select!{|t| visited.include?(t) }
              reachable << child if visited.include?(child)
              direct_parents.each{|t| reachable << t }
            end
            if options[:graph] && partition_index == options[:selected]
              File.open(options[:graph],"w") do |output|
                parents.each do |child,direct_parents|
                  direct_parents.each do |parent|
                    parent_id = name_service.convert_ruby_term(parent).id
                    child_id = name_service.convert_ruby_term(child).id
                    output.puts "#{parent}-#{term_ids[parent_id]} <- #{child}-#{term_ids[child_id]}"
                  end
                end
              end
            end

            index_to_term = reachable.to_a
            term_to_index = Hash[index_to_term.map.with_index{|t,i| [t,i] }]
            distance_table = Array.new(index_to_term.size){ Array.new(index_to_term.size) }
            index_to_term.size.times.each do |index|
              distance_table[index][index] = 0
            end
            index_to_id = {}
            index_to_term.each.with_index do |term,index|
              index_to_id[index] = name_service.convert_ruby_term(term).id
            end

            parents.each do |child,direct_parents|
              direct_parents.each do |parent|
                child_id = term_to_index[child]
                parent_id = term_to_index[parent]
                #if child_id > parent_id
                #  child_id,parent_id = parent_id,child_id
                #end
                distance_table[child_id][parent_id] = 1
                distance_table[parent_id][child_id] = 1
              end
            end

            distance_table.size.times do |pivot|
              distance_table.size.times do |row|
                distance_table.size.times do |column|
                  left_distance = distance_table[row][pivot]
                  right_distance = distance_table[pivot][column]
                  next if left_distance.nil? || right_distance.nil?
                  if distance_table[row][column].nil? || distance_table[row][column] > left_distance + right_distance
                    distance_table[row][column] = left_distance + right_distance
                  end
                end
              end
            end

            if options[:verbose] && partition_index == options[:selected]
              print "    "
              distance_table.size.times{|i| print " %2i" % i }
              puts
              puts  "-" * (4 + distance_table.size * 3)
              distance_table.size.times do |row_index|
                print "%2i: " % row_index
                distance_table.size.times do |column_index|
                  if distance_table[row_index][column_index]
                    print " %2i" % distance_table[row_index][column_index]
                  else
                    print "  X".hl(:red)
                  end
                end
                puts "  #{index_to_term[row_index]}"
              end
              puts
            end
            distances = {}
            distance_table.size.times do |row_index|
              distances[index_to_term[row_index]] = 0
              distance_table.size.times do |column_index|
                begin
                  if row_index == column_index
                    next
                  elsif row_index < column_index
                    distances[index_to_term[row_index]] += distance_table[row_index][column_index] * term_ids[index_to_id[column_index]]
                  else
                    distances[index_to_term[row_index]] += distance_table[column_index][row_index] * term_ids[index_to_id[column_index]]
                  end
                rescue => ex
                  puts "#{index}. #{head.join(" ")} #{partition_index}. #{partition}"
                  puts ex
                  puts "row: #{index_to_term[row_index]} - #{row_index}, column #{index_to_term[column_index]} - #{column_index}"
                  distances[index_to_term[row_index]] += 100
                end
              end
            end
            if terms.size == 0 || distances.size == 0
              next
            elsif terms.size == 1
              centroid = terms.first.to_ruby
            else
              centroid = distances.sort_by{|k,v| v }.first.first
            end
            if options[:verbose] && partition_index == options[:selected]
              max_length = distances.keys.map{|k| k.size }.max
              distances.sort_by{|k,v| v }.each do |term,value|
                puts "%-#{max_length}s : #{value}" % term
              end
            end
            puts "#{centroid}\n".hl(:green) if options[:verbose]
            partition.each do |term,support|
              next unless terms.include?(term)
              second_order_partition[centroid][term.id] = support
            end
          rescue Interrupt
            raise
          rescue Exception => ex
            puts ex
            puts ex.backtrace[0..10]
            select_highest_support(partition,second_order_partition)
          end
        end
        output_tuple = head.dup
        second_order_partition.map{|k,vs| [k,vs.inject(0){|s,(k,v)| s + v }] }.sort_by{|k,v| -v }.each do |centroid,support|
          output_tuple << name_service.convert_ruby_term(centroid).id << centroid.to_s << support
        end
        output << output_tuple
      rescue Interrupt
        break
      end
    end
    Progress.stop unless options[:verbose]
  end
end
