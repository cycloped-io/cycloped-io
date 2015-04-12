#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
$:.unshift 'lib'
require 'slop'
require 'csv'
require 'cycr'
require 'progress'
$:.unshift '../category-mapping/lib'
require 'mapping/service/cyc_name_service'
require 'mapping/cyc_term'
require 'benchmark'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -c cyc_to_umbel.csv -m mapping.csv -u umbel_categories.csv -n unmapped_categories.csv -i missing_cycs.csv -r remaining_umbels.csv\n" +
             'Exports statistics of unique Cyc and UMBEL terms.'

  on :c=, :cyc_to_umbel, 'Cyc to UMBEL mapping', required: true
  on :m=, :mapping, 'Category mapping to Cyc', required: true
  on :u=, :umbel_to_categories, 'UMBEL concepts and their corresponding Wikipedia categories', required: true
  on :n=, :unmapped, 'Unmapped, qualified Wikipedia categories', required: true
  on :i=, :missing, 'Cyc concepts that are missing in UMBEL', required: true
  on :r=, :remaining, 'Remaining UMBEL concepts that are not mapped', required: true
  on :h=, :host, 'Cyc host (localhost)', default: 'localhost'
  on :p=, :port, 'Cyc port (3601)', as: Integer, default: 3601
  on :d=, :database, 'ROD database', default: '../rlp/data/en-2013'
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

=begin
3. The analysis of names of categories that haven't evoked any candidate
mapping.
=end

include Rlp::Wiki
Database.instance.open_database(options[:database])

cyc = Cyc::Client.new(host: options[:host], port: options[:port], cache: true)
name_service = Mapping::Service::CycNameService.new(cyc)


cyc_to_umbel=Hash.new
CSV.open(options[:cyc_to_umbel]) do |csv_cyc_to_umbel|
  csv_cyc_to_umbel.each do |cycid, umbel|
    cyc_to_umbel[cycid]=umbel
  end
end

direct = Set.new
all_genls = Set.new

wikipedia_categories = Set.new
umbel_to_categories = Hash.new

CSV.open(options[:mapping]) do |csv_mapping|
  csv_mapping.with_progress do |name, cycid, cyc_name|
    wikipedia_categories.add name
    if cyc_to_umbel.include? cycid
      (umbel_to_categories[cyc_to_umbel[cycid]] ||=[]) << name
    end

    next if direct.include? cycid
    direct.add cycid


    term =name_service.find_by_id(cycid)
    next if term.nil?
    genls = cyc.all_genls(term)
    next if genls.nil?
    all_genls.merge genls.map { |term| name_service.convert_ruby_term(term).id }
  end
end

#1. The number of parent concepts that were not included in the numbers
puts 'Unique direct Cyc ids: '+(direct.size.to_s)
puts 'Unique generalized Cyc ids: '+((all_genls|direct).size.to_s)
puts 'Unique generalized minus direct Cyc ids: '+((all_genls-direct).size.to_s)

umbel_direct = Set.new(direct.map { |cycid| cyc_to_umbel[cycid] })
umbel_all_genls = Set.new(all_genls.map { |cycid| cyc_to_umbel[cycid] })

puts 'Unique direct UMBEL ids: '+(umbel_direct.size.to_s)
puts 'Unique generalized UMBEL ids: '+((umbel_all_genls|umbel_direct).size.to_s)
puts 'Unique generalized minus direct UMBEL ids: '+((umbel_all_genls-umbel_direct).size.to_s)

#2. The list of Cyc concepts that are missing in UMBEL
CSV.open(options[:missing], 'w') do |csv|
  direct.each do |cycid|
    if !cyc_to_umbel.include? cycid
      term =name_service.find_by_id(cycid)
      csv << [term.to_ruby, term.id]
    end
  end
end

#4. The 4500 mapped UMBEL concepts and their corresponding Wikipedia categories.
CSV.open(options[:umbel_to_categories], 'w') do |csv|
  umbel_to_categories.each do |umbel, names|
    csv << [umbel, *names]
  end
end

#3. Under #3, a listing of unmapped, qualified Wikipedia categories, and

CSV.open(options[:unmapped], 'w') do |csv|
  Category.with_progress do |category|
    next if !category.regular?
    next if !category.plural?
    next if wikipedia_categories.include? category.name
    csv << [category.name]
  end
end

# remaining 20k concepts are not mapped
umbels = Set.new(cyc_to_umbel.map{|k,v| v})
remaining=umbels-Set.new(umbel_to_categories.map{|k,v| k})
CSV.open(options[:remaining], 'w') do |csv|
  remaining.each do |umbel|
    csv << [umbel]
  end
end

