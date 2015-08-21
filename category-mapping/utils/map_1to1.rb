#!/usr/bin/env ruby

require 'bundler/setup'
$:.unshift 'lib'
require 'slop'
require 'progress'
require 'rlp/wiki'
require 'cycr'
require 'colors'
require 'csv'
require 'set'
require 'rod/rest'
require 'syntax'
require 'mapping'
require 'auto_serializer'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -i core_support.csv -o cyc_to_categories_1to1.csv -w categories_to_cyc_1to1.csv\n"+
             'Create 1 to 1 mapping between Cyc and Wikipedia categories.'

  on :i=, :input, 'Input mapping file', required: true
  on :o=, :output, 'Output mapping file - Cyc to Wiki', required: true
  on :w=, :wiki_output, 'Output mapping file - Wiki to Cyc', required: true
  on :p=, :port, 'Cyc port', as: Integer, default: 3601
  on :h=, :host, 'Cyc host', default: 'localhost'

end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

cyc = Cyc::Client.new(port: options[:port], host: options[:host], cache: true)
$name_service = Mapping::Service::CycNameService.new(cyc)

def read_cyc_to_wiki(path)
  cyc_to_wiki = Hash.new { |hash, key| hash[key] = [] }
  CSV.open(path) do |input|
    input.with_progress do |name, phrase, *types|
      types = types.each_slice(4).to_a
      types.each do |cyc_id, cyc_name, support, signals|
        cyc_to_wiki[cyc_id] << [name, support.to_i, signals.to_i]
      end
    end
  end
  cyc_to_wiki.default = nil
  return cyc_to_wiki
end

def exact_mapping(path)
  cyc_to_wiki = AutoSerializer.auto(:read_cyc_to_wiki, path,)

  cyc_to_wiki_filtered = {}
  cyc_to_wiki.with_progress do |cyc_id, wikis|
    cyc_term = $name_service.find_by_id(cyc_id)
    labels = $name_service.labels(cyc_term).map { |label| label.downcase } #+ [name_service.canonical_label(cyc_term)]
    wikis.reject! { |name, support, signals| !labels.include?(name.downcase) }
    if !wikis.empty?
      cyc_to_wiki_filtered[cyc_id] = wikis
    end
  end

  return cyc_to_wiki_filtered
end

cyc_to_wiki = AutoSerializer.auto(:exact_mapping, options[:input])


supports = Hash.new
wiki_to_cyc = Hash.new { |hash, key| hash[key] = [] }

cyc_to_wiki.each do |cyc_id, wikis|
  wikis.each do |name, support, signals|
    wiki_to_cyc[name] << cyc_id
    supports[[name, cyc_id]] = [support, signals]
  end
end

queue = []

supports.each do |key, value|
  name, cyc_id = key
  support, signals = value
  queue << [name, cyc_id, support] if support>0
end

queue.sort_by! { |name, cyc_id, support| -support }

assigned = Hash.new { |hash, key| hash[key] = [] }
max_cyc = Hash.new(0)
max_wiki = Hash.new(0)

queue.each do |name, cyc_id, support|
  if support>=max_wiki[name] && support>=max_cyc[cyc_id]
    assigned[cyc_id] << name
  end

  max_wiki[name]=[max_wiki[name], support].max
  max_cyc[cyc_id]=[max_cyc[cyc_id], support].max
end

stats=Hash.new(0)
wiki_stats = Hash.new { |hash, key| hash[key] = [] }

CSV.open(options[:wiki_output], 'w') do |wiki_output|
  CSV.open(options[:output], 'w') do |output|
    assigned.each do |cyc_id, wikis|
      output << [cyc_id, $name_service.find_by_id(cyc_id).to_ruby.to_s]+wikis
      stats[wikis.size]+=1
      if wikis.size>1
        p $name_service.find_by_id(cyc_id), wikis
      end
      wikis.each do |wiki|
        wiki_stats[wiki] << cyc_id
        wiki_output << [wiki, cyc_id, $name_service.find_by_id(cyc_id).to_ruby.to_s]
      end
    end
  end
end

stats.each do |key, count|
  puts 'Cyc terms with %s category/ies assigned: %s' % [key, count]
end

c=0
wiki_stats.each do |wiki, cyc_ids|
  if cyc_ids.size>1
    c+=1
    p wiki, cyc_ids.map { |cyc_id| $name_service.find_by_id(cyc_id) }
  end
end
puts 'Categories assigned to more than one Cyc term: %s' % [c]