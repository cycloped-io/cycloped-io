#!/bin/env ruby
# encoding: utf-8
require 'wordnet'
require 'bundler/setup'
require 'rlp/wiki'
require 'cycr'

require 'csv'
require 'progress'
require 'slop'
require '../category-parsing/lib/nouns/nouns'


include Rlp::Wiki


options = Slop.new do
  banner "#{$PROGRAM_NAME} -o semantic_parents_wordnet.csv -c semantic_parents.csv [-d database] [-p port] [-h host]\n"+
             'Finds semantic parents of Wikipedia categories using data from WordNet.'

  on 'o', 'output', 'Output mapping file semantic_parents_wordnet.csv', argument: :mandatory, required: true
  on 'c', 'parents', 'Input mapping file semantic_parents.csv', argument: :mandatory, required: true
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

$nouns = Nouns.new('data/nouns')

$cache = Hash.new


$noun_index = WordNet::NounIndex.instance

$categories = Hash.new

f = CSV.open(options[:parents])
f.each do |row|
  row.map! { |id| id.to_i }
  category, *parents = row
  $categories[category] = parents.map { |c| Category.find_by_wiki_id(c) }
end


def wordnet_genls?(child, parent)
  hypernyms = child.expanded_hypernym
  return hypernyms.include?(parent)
end

def genls_cache(cyc_term, cyc_parent)
  if $cache.has_key?([cyc_term, cyc_parent])

    return $cache[[cyc_term, cyc_parent]]
  end
  result = wordnet_genls? cyc_term, cyc_parent
  $cache[[cyc_term, cyc_parent]] = result
  return result
end

def candidates(name)
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
    lemmas = $noun_index.find(noun)
    if not lemmas.nil?
      cyc_categories += lemmas.synsets
    end
  end

  return cyc_categories.uniq
end

def genls(cyc_categories, cyc_parents)
  return false if cyc_categories.nil? or cyc_parents.nil?

  cyc_categories.each do |cyc_term|
    cyc_parents.each do |cyc_parent|
      if genls_cache(cyc_term, cyc_parent)
        return true
      end
    end
  end

  return false
end

$cache2 = Hash.new

def any_genls(category, parent_category)
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
    cyc_categories += candidates(head)
  end


  cyc_parents = []
  parent_heads.each do |head|
    cyc_parents += candidates(head)
  end


  return true if genls(cyc_categories, cyc_parents) or genls(cyc_parents, cyc_categories)


  return false
end

def any_genls_cache(category, parent_category)
  return $cache2[[category, parent_category]] if $cache2.has_key?([category, parent_category])
  result = any_genls(category, parent_category)
  $cache2[[category, parent_category]] = result
  return result
end


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


without_semantic_parents = 0
with_semantic_parent = 0


fsem = CSV.open(options[:output], 'w')

Progress.start(Category.count)
Category.each.with_index do |category, index|
  Progress.set index
  next unless category.regular?
  next unless category.plural?

  next if $categories.include? category.wiki_id

  parents = []
  any_regular_parent=false
  begin
    #next unless category.name == "Social conventions"
    category.parents.each do |parent|
      next unless parent.regular?
      next unless parent.plural?


      hyponym = any_genls_cache(category, parent)

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
      p category, parents
      with_semantic_parent+=1
    elsif any_regular_parent
      without_semantic_parents+=1
    end
  rescue Interrupt
    puts
    break
  rescue Exception => ex
    STDERR.puts category.name
    STDERR.puts ex
    STDERR.puts ex.backtrace[0..3]
  end
end
Progress.stop

fsem.close


puts 'Statistics covers only regular and plural categories with at least one plural and regular parent.'
puts 'Categories with at least one semantic parent: '+with_semantic_parent.to_s
puts 'Categories without semantic parents and with regular and plural parent: '+without_semantic_parents.to_s


