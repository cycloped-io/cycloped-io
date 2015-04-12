#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'rlp/wiki'

include Rlp::Wiki
Database.instance.open_database(ARGV[0])

[
  [:concepts,Category,"Category:",""],
  [:children,Category,"Category:","Category:"],
  [:parents,Category,"Category:","Category:"]
].each do |relation,main_class,parent_prefix,child_prefix|
  next unless relation == :concepts
  puts "## Number of #{relation}\n\n"
  histogram = main_class.inject(Hash.new(0)){|h,c| h[c.__send__(relation).count] += 1 ; h }
  mean = histogram.inject(0){|s,(k,v)| s + k * v } / main_class.count.to_f
  median = histogram.sort_by{|k,v| k }.inject(0){|s,(k,v)| break k if(s + v > main_class.count / 2); s + v}
  puts "### Mean %.2f\n\n" % mean
  puts "### Median %i\n\n" % median
  puts "### Samples \n\n"
  3.times do |index|
    puts "#### With #{index} #{relation}\n\n"
    main_class.inject([]) do |selected,parent| 
      break selected if selected.size == 5
      selected + (parent.__send__(relation).count == index && rand < 0.1 ? [parent] : [])
    end.each do |parent| 
      puts " * [#{parent.name}](http://en.wikipedia.org/wiki/#{parent_prefix}#{parent.name.gsub(" ","_")})"
      parent.__send__(relation).each do |child|
        puts "   * [#{child.name}](http://en.wikipedia.org/wiki/#{child_prefix}#{child.name.gsub(" ","_")})"
      end
    end
    puts
  end
  puts "### Histogram\n\n"
  puts "| children count | parent count |\n"
  puts "|---|---|\n"
  histogram.sort{|(k1,v1),(k2,v2)| v1 == v2 ? k1 <=> k2 : v2 <=> v1 }.
    select{|k,v| v > 100 }.each{|k,v| puts "| #{k} | #{v} |"}
end


Database.instance.close_database
