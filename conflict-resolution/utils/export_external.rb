#!/usr/bin/env ruby

require 'bundler/setup'
require 'csv'
require 'slop'
require 'progress'
require 'cycr'
require 'colors'
$:.unshift "../category-mapping/lib"
require 'mapping/service/cyc_name_service'
require 'mapping/cyc_term'

options = Slop.new do
  banner "#{$PRGORAM_NAME} -f partitions.csv -o classification.csv -m mapping.csv\n" +
    "Export classification to external classification scheme with one type per article"

  on :f=, :input, "Input file with partitions", required: true
  on :o=, :output, "Output file with classification", required: true
  on :m=, :mapping, "File with mapping from Cyc terms to external types", required: true
  on :h=, :host, "Cyc host (localhost)", default: "localhost"
  on :p=, :port, "Cyc port (3601)", default: 3601, as: Integer
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

cyc = Cyc::Client.new(port: options[:port], host: options[:host],cache: true)
service = Mapping::Service::CycNameService.new(cyc)

mapping = Hash.new{|h,e| h[e] = [] }
CSV.open(options[:mapping],"r:utf-8") do |input|
  input.each do |cyc_id,cyc_name,external_id|
    cyc_term = service.find_by_id(cyc_id)
    mapping[cyc_term.to_ruby] << external_id
  end
end

CSV.open(options[:input],"r:utf-8") do |input|
  CSV.open(options[:output],"w") do |output|
    input.with_progress do |row|
      article_name = row.shift
      next if row.empty?
      output_row = [article_name]
      partitions = []
      # find best partition
      row.each do |element|
        case element
        when "P"
          partitions << []
        when /^\d+(\.\d+)?$/
          partitions.last << element.to_f
        else
          partitions.last << element
        end
      end
      best_partition = partitions.sort_by{|support,*rest| -support }.first
      unless best_partition[1..-1].empty?
        supports = Hash.new(0)
        # select most spectific terms
        terms_with_support = best_partition[1..-1].each_slice(3).map do |cyc_id,cyc_name,support|
          [service.find_by_id(cyc_id),support]
        end
        terms_with_updated_support = []
        terms_with_support.each do |child,child_support|
          has_children = false
          support = child_support
          terms_with_support.each do |parent,parent_support|
            next if child == parent
            if cyc.with_any_mt{|c| c.genls?(parent,child) }
              has_children = true
              break
            end
            if cyc.with_any_mt{|c| c.genls?(child,parent) }
              support += parent_support
            end
          end
          unless has_children
            terms_with_updated_support << [child,support]
          end
        end
        terms_with_updated_support.each do |cyc_term,support|
          parent_term,external_ids,genls_count =
            (cyc.with_any_mt{|c| c.all_genls(cyc_term) } || []).map do |generalization|
              unless mapping[generalization].empty?
                [generalization,mapping[generalization],cyc.with_any_mt{|c| c.length {|c| c.all_genls(generalization)}}.to_i ]
              end
            end.compact.sort_by{|_,_,c| -c }.first
          if parent_term
            supports[external_ids] += support
          end
        end
        external_ids, support = supports.sort_by{|_,s| -s }.first
        if external_ids
          external_ids.each do |external_id|
            output_row << external_id
          end
        else
          puts "Exteranl id for #{article_name} with patition #{best_partition} missing".hl(:yellow)
        end
      end
      output << output_row
    end
  end
end
