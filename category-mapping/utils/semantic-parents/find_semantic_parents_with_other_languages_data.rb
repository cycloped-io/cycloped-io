#!/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
require 'cycr'
require 'csv'
require 'progress'
require 'slop'
require '../category-parsing/lib/nouns/nouns'
$:.unshift 'lib'
require 'mapping/cyc_term'
require 'mapping/service/cyc_name_service'
require 'mapping/wikipedia_name_converter'

include Rlp::Wiki


options = Slop.new do
  banner "#{$PROGRAM_NAME} -c semantic_parents.csv -o semantic_parents_other_languages.csv [-d database] [-p port] [-h host]\n"+
             'Finds semantic parents of Wikipedia categories using data from other languages.'

  on 'o', 'output', 'Output mapping file semantic_parents_other_languages.csv', argument: :mandatory, required: true
  on 'c', 'parents', 'Input mapping file semantic_parents.csv', argument: :mandatory, required: true
  on 'l', 'languages', 'Input parents from other languages other_parents.csv', argument: :mandatory, required: true
  on 'd', 'database', 'ROD database with Wikipedia data', argument: :mandatory
  on 'p', 'port', 'Cyc port', as: Integer
  on 'h', 'host', 'Cyc host'
end
begin
  options.parse
rescue Slop::MissingOptionError
  puts options
  exit
end

Database.instance.open_database(options[:database] || '../rlp/data/en-2013')

cyc = Cyc::Client.new(port: options[:port] || 3601, host: options[:host] || 'localhost', cache: true)
name_service = Mapping::Service::CycNameService.new(cyc)

$categories = Hash.new

f = CSV.open(options[:parents])
f.each do |row|
  row.map! { |id| id.to_i }
  category, *parents = row
  $categories[category] = parents.map { |c| Category.find_by_wiki_id(c) }
end

$languages = Hash.new

f = CSV.open(options[:languages])
f.each do |row|
  row.map! { |id| id.to_i }
  category, *parents = row
  $languages[category] = parents.map { |c| Category.find_by_wiki_id(c) }
end


$nouns = Nouns.new('data/nouns')

$cache = Hash.new

def genls_cache(cyc, cyc_term, cyc_parent)
  return cyc.genls? cyc_term, cyc_parent
end

def candidates(name_service, name)
  names = []

  if $nouns.plural?(name)
    names += $nouns.singularize(name)
  else
    names.push name
  end

  if $nouns.plural?(name.downcase)
    names += $nouns.singularize(name.downcase)
  else
    names.push name.downcase
  end

  cyc_categories = []
  names.uniq.each do |noun|
    cyc_categories += name_service.find_by_name(noun)
  end

  return cyc_categories.uniq
end

def genls(cyc, cyc_categories, cyc_parents)
  return false if cyc_categories.nil? or cyc_parents.nil?

  cyc_categories.each do |cyc_term|
    cyc_parents.each do |cyc_parent|
      if genls_cache(cyc, cyc_term, cyc_parent)
        return true
      end
    end
  end

  return false
end

$cache2 = Hash.new

def any_genls(cyc, name_service, category, parent_category)
  category_heads = category.heads
  parent_heads = parent_category.heads
  category_heads.push category.head if category.head
  parent_heads.push parent_category.head if parent_category.head
  category_heads.uniq!
  parent_heads.uniq!

  if (category_heads.map { |head| head.downcase } & parent_heads.map { |head| head.downcase }).size > 0
    return true
  end

  cyc_categories = []
  category_heads.each do |head|
    cyc_categories += candidates(name_service, head)
  end


  cyc_parents = []
  parent_heads.each do |head|
    cyc_parents += candidates(name_service, head)
  end

  return true if genls(cyc, cyc_categories, cyc_parents) or genls(cyc, cyc_parents, cyc_categories)

  begin
    cyc_categories2 = name_service.find_by_name(category.name)
    return true if genls(cyc, cyc_categories2, cyc_parents) or genls(cyc, cyc_parents, cyc_categories2)
  rescue Cyc::CycError
  end

  return false if cyc_categories.empty? and cyc_categories2.empty?

  begin
    cyc_parents2 = name_service.find_by_name(parent_category.name)
    return true if genls(cyc, cyc_categories, cyc_parents2) or genls(cyc, cyc_parents2, cyc_categories)
    return true if genls(cyc, cyc_categories2, cyc_parents2) or genls(cyc, cyc_parents2, cyc_categories2)
  rescue Cyc::CycError
  end

  return false
end

def any_genls_cache(cyc, name_service, category, parent_category)
  return $cache2[[category, parent_category]] if $cache2.has_key?([category, parent_category])
  result = any_genls(cyc, name_service, category, parent_category)
  $cache2[[category, parent_category]] = result
  return result
end

without_semantic_parents = 0
with_semantic_parent = 0


def create_cycle?(category, parent)
  ancestors = Set.new

  stack = [parent]
  while not stack.empty?
    ancestor = stack.pop
    next if ancestors.include? ancestor
    ancestors.add ancestor

    next if not $categories.has_key? ancestor.wiki_id

    $categories[ancestor.wiki_id].each do |ancestor_parent|
      stack.unshift ancestor_parent
      if category == ancestor_parent
        puts 'Cycle: ' + category.name + ' -> ' + parent.name
        return true
      end
    end
  end

  return false
end


fsem = CSV.open(options[:output], 'w')

Progress.start(Category.count)
Category.each.with_index do |category, index|
  next unless category.regular?
  next unless category.plural?
  parents = []
  any_regular_parent=false

  next if $categories.include? category.wiki_id

  normal_parents = []
  if $languages.has_key? category.wiki_id
    normal_parents += $languages[category.wiki_id]
  else
    next
  end

  normal_parents.select! { |c| c.regular? and c.plural? }
  normal_parents.uniq!
  normal_parents.delete category

  normal_parents.each do |parent|
    next unless parent.regular?
    next unless parent.plural?

    hyponym = any_genls_cache(cyc, name_service, category, parent)

    if hyponym
      parents.push parent
    end
    any_regular_parent=true
  end

  parents.select! { |parent|
    not create_cycle?(category, parent)
  }

  if not parents.empty?
    fsem << [category.wiki_id].concat(parents.map { |c| c.wiki_id })
    with_semantic_parent+=1
  elsif any_regular_parent
    without_semantic_parents+=1
  end

  Progress.set index
end
Progress.stop

fsem.close


puts 'Statistics covers only regular and plural categories with at least one plural and regular parent.'
puts 'Categories with at least one semantic parent: '+with_semantic_parent.to_s
puts 'Categories without semantic parents and with regular and plural parent: '+without_semantic_parents.to_s

# LAST RUN

#100.0% (elapsed: 5.4m)
#Statistics covers only regular and plural categories with at least one plural and regular parent.
#Categories with at least one semantic parent: 1770
#Categories without semantic parents and with regular and plural parent: 7211