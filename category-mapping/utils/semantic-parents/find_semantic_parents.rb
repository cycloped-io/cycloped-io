#!/usr/bin/env ruby
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
require 'umbel/serializer'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -o semantic_parents.csv [-d database] [-p port] [-h host]\n"+
             'Finds semantic parents of Wikipedia categories.'

  on :o=, 'output', 'Output mapping file semantic_parents.csv', required: true
  on :d=, 'database', 'ROD database with Wikipedia data', required: true
  on :p=, 'port', 'Cyc port', as: Integer, default: 3601
  on :h=, 'host', 'Cyc host', default: 'localhost'
end
begin
  options.parse
rescue Slop::MissingOptionError
  puts options
  exit
end

include Rlp::Wiki
Database.instance.open_database(options[:database])

cyc = Cyc::Client.new(port: options[:port], host: options[:host], cache: true)
name_service = Mapping::Service::CycNameService.new(cyc)

$nouns = Umbel::Serializer.auto(Nouns)

$cache = Hash.new

def genls_cache(cyc, cyc_term, cyc_parent)
  return $cache[[cyc_term, cyc_parent]] if $cache.has_key?([cyc_term, cyc_parent])
  result = cyc.genls? cyc_term, cyc_parent
  $cache[[cyc_term, cyc_parent]] = result
  return result
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


CSV.open(options[:output], 'w') do |fsem|
  Category.with_progress do |category|
    next unless category.regular?
    next unless category.plural?
    parents = []
    any_regular_parent=false
    category.parents.each do |parent|
      next unless parent.regular?
      next unless parent.plural?

      hyponym = any_genls_cache(cyc, name_service, category, parent)

      if hyponym
        parents.push parent
      end
      any_regular_parent=true
    end

    if not parents.empty?
      fsem << [category.wiki_id].concat(parents.map { |c| c.wiki_id })
      with_semantic_parent+=1
    elsif any_regular_parent
      without_semantic_parents+=1
    end
  end
end

puts 'Statistics covers only regular and plural categories with at least one plural and regular parent.'
puts 'Categories with at least one semantic parent: '+with_semantic_parent.to_s
puts 'Categories without semantic parents and with regular and plural parent: '+without_semantic_parents.to_s


# LAST RUN OUTPUT

#100.0% (elapsed: 1.4h)
#Statistics covers only regular and plural categories with at least one plural and regular parent.
#Categories with at least one semantic parent: 574189
#Categories without semantic parents and with regular and plural parent: 28742