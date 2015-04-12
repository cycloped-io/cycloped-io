#!/usr/bin/env ruby
# encding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
require 'irb'
require 'set'
require 'progress'
require 'csv'

'Counts article coverage'

include Rlp::Wiki

apohl = []
sd = []
auto = []
CSV.open('../category-mapping/data/wikipedia_category_cyc_mapping.csv').each do |row|
  apohl.push row[1]
end
CSV.open('../category-mapping/data/SD_umbel_wiki_cyc_filtered.csv').each do |row|
  sd.push row[0]
end
CSV.open('../category-mapping/data/automatic_mapping_disambiguated_only.csv', 'r:utf-8').each do |row|
  auto.push row[0]
end

Database.instance.open_database(ARGV[0])

concepts_apohl = Set.new
concepts_sd = Set.new
concepts_auto = Set.new

def get_all_subcategory_concpets(category)
  concepts = Set.new
  
  stack = [category]
  
  while not stack.empty?
    category = stack.pop
    if $checked.include? category
      next
    end
    $checked.add category

    concepts.merge category.concepts
    
    category.get_semantic_children.each do |child|
      stack.push child
    end
  end
  return concepts
end


$checked = Set.new
auto.with_progress do |cat|
  category = Category.find_by_name cat
  if category.nil?
    p 'nil',cat
    next
  end
  concepts = get_all_subcategory_concpets(category)
  concepts_auto.merge concepts
end

p 'Automatic articles coverage: '+concepts_auto.size.to_s


$checked = Set.new
apohl.with_progress do |cat|
  category = Category.find_by_name cat
  if category.nil?
    p 'nil',cat
    next
  end
  
  #p category
  #next if category.name != 'Populated places'
  concepts = get_all_subcategory_concpets(category)
  concepts_apohl.merge concepts
  #p concepts.size
end

p 'A.Pohl articles coverage: '+concepts_apohl.size.to_s

$checked = Set.new
sd.with_progress do |cat|
  category = Category.find_by_name cat
  #p category
  concepts = get_all_subcategory_concpets(category)
  concepts_sd.merge concepts
  #p concepts.size
end


p 'Automatic articles coverage: '+concepts_auto.size.to_s
p 'A.Pohl articles coverage: '+concepts_apohl.size.to_s
p 'SD articles coverage: '+concepts_sd.size.to_s
p 'Intersection of A.Pohl and SD: '+(concepts_sd & concepts_apohl).size.to_s
p 'Intersection of A.Pohl and auto: '+(concepts_auto & concepts_apohl).size.to_s

Database.instance.close_database