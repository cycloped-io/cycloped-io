#!/usr/bin/env ruby
# encoding: utf-8


require 'bundler/setup'
$:.unshift "../category-mapping/lib"
require 'rlp/wiki'
require 'progress'
require 'csv'
require 'slop'
require 'set'
require 'colors'
require 'cycr'
require 'mapping'
require 'experiment_arguments_log/auto'
require 'syntax'
require 'nouns/nouns'
require 'yajl'
require 'auto_serializer'
require 'dbm'



class Node #article or category
  attr_accessor :name, :relations, :information_nodes

  def initialize(name)
    @name=name
    @relations = []
    @information_nodes = []
  end

  def add_relation(relation)
    relations << relation
  end

  def add_information(information_node)
    @information_nodes << information_node
  end

  def all_informations
    informations = @information_nodes.dup
    @relations.each do |relation|
      information_nodes.concat(relation.node.information_nodes)
    end
    return informations
  end

  def score_informations(name_service, information_node_name=nil)
    @information_nodes.each do |information_node|
      next if !information_node.assigned_type.nil?
      information_node.candidates.each do |candidate|
        next if !information_node_name.nil? && information_node.name==information_node_name

        @information_nodes.each do |other_information_node|
          next if information_node == other_information_node
          score = candidate.calculate_score(other_information_node, name_service)
          candidate.add_score(score)
        end

        self.relations.each do |relation|
          score = Score.new
          relation.node.information_nodes.each do |other_information_node|
            score.add(candidate.calculate_score(other_information_node, name_service))
          end
          #if score < -1 then -1 - odlaczamy kategorie
          if score.max_value < -1.0
            # score.count = 1
            score.max_value = -1.0
          end
          candidate.add_score(score)
        end

      end

      #save best candidate for information_node
      information_node.best_candidate = information_node.candidates.max_by { |candidate| candidate.score.value }
    end
  end
end

class Relation
  attr_accessor :name, :node

  def initialize(name, node)
    @name = name
    @node = node
  end
end

class InformationNode #Namespace: fsX, headX
  attr_accessor :name, :candidates, :assigned_type, :best_candidate

  def initialize(name)
    @name=name
    @candidates=[]
    @assigned_type = nil
  end

  def add_candidate(candidate)
    @candidates << candidate
  end


end

class Candidate
  attr_accessor :cyc_id, :phrases, :score

  def initialize(cyc_id, phrases)
    @cyc_id = cyc_id
    @phrases=phrases
    @score = Score.new
  end

  def cyc_term(name_service)
    name_service.find_by_id(@cyc_id)
  end

  def calculate_score(information_node, name_service)
    score = Score.new



    cyc = name_service.cyc

    genls=igenls=nondisjoint=disjoint=isa=iisa=0

    if !information_node.assigned_type.nil?
      candidates = [Candidate.new(information_node.assigned_type, [])]
    else
      candidates = information_node.candidates
    end
    candidates.each do |candidate|
      #TODO phrases rejection
      if any_element_of_list_in_list(@phrases, candidate.phrases)
        next
      end
      cyc_term2 = candidate.cyc_term(name_service)

      #TODO isa
      if cyc.with_any_mt{|c| c.genls?(cyc_term(name_service), cyc_term2)}
        # p ['genls', cyc_term(name_service), cyc_term2, @phrases, candidate.phrases]
        genls+=1
      elsif cyc.with_any_mt{|c| c.genls?(cyc_term2, cyc_term(name_service)) }
        # p ['igenls', cyc_term(name_service), cyc_term2, @phrases, candidate.phrases]
        igenls+=1
      elsif cyc.with_any_mt{|c| c.isa?(cyc_term(name_service), cyc_term2)} # cyc.isa?(cyc_term(name_service), cyc_term2)
        # p ['isa', cyc_term(name_service), cyc_term2, @phrases, candidate.phrases]
        isa+=1
      elsif cyc.with_any_mt{|c| c.isa?(cyc_term2, cyc_term(name_service))} #cyc.isa?(cyc_term2, cyc_term(name_service))
        # p ['iisa', cyc_term(name_service), cyc_term2, @phrases, candidate.phrases]
        iisa+=1
      elsif !cyc.with_any_mt{|c| c.disjoint_with?(cyc_term(name_service), cyc_term2)}
        # p ['nondisjoint', cyc_term(name_service), cyc_term2, @phrases, candidate.phrases]
        nondisjoint+=1
      else
        # p ['disjoint', cyc_term(name_service), cyc_term2, @phrases, candidate.phrases]
        disjoint+=1
      end

      break if genls>0
    end



    scores = []
    if genls>0
      scores<<1.0
    end
    if igenls>0
      scores<<0.7
    end
    if isa>0
      scores<<0.5
    end
    if iisa>0
      scores<<0.4
    end
    if nondisjoint>0
      scores<<0.1
    end
    if disjoint>0
      scores<<-1.0
    end

    if scores.size>0
      score.count=1
      # score.min_value=scores.min
      score.max_value=scores.max
    end



    return score
  end

  def add_score(score)
    @score.add(score)
  end
end

class Score
  attr_accessor :max_value, :count

  def initialize
    @max_value=0.0
    # @min_value=0.0
    @count=0
  end

  def add(score)
    @max_value += score.max_value
    # @min_value += score.min_value
    @count += score.count
  end

  def value
    @max_value*@count
  end
end

def any_element_of_list_in_list(list1, list2) #TODO
  list2.map!{|e| singularize(e.downcase)}
  list2.flatten!
  list2.uniq!
  list1.map!{|e| singularize(e.downcase)}
  list1.flatten!
  list1.uniq!

  list1.each do |element|
    if list2.include? element
      return true
    end
  end
  return false
end


$nouns = Nouns.new

def singularize(name)
  names = [name]
  singularized_heads = $nouns.singularize(name)
  if not singularized_heads.nil?
    names.concat singularized_heads
  end
  names
end


def build_information_nodes(dbm_structure, name)
  information_nodes = []
  dbm_structure.each do |namespace, namespace_candidates|
    information_node = InformationNode.new(namespace)

    if $assigned.include? ([name,namespace].to_s)
      information_node.assigned_type = $assigned[[name,namespace].to_s]
    else
      namespace_candidates.each do |cyc_id, phrases|
        information_node.add_candidate(Candidate.new(cyc_id, phrases))
      end
    end
    information_nodes << information_node

  end
  information_nodes
end

def build_graph_for_category(category_name)
  category = Category.find_by_name(category_name)
  articles = category.concepts
  parents = category.parents
  children = category.children

  category_node = Node.new(category_name)
  ac = $category_candidates[category_name]
  if not ac.nil?
    ac = Yajl::Parser.parse(ac)


    build_information_nodes(ac, 'Category:'+category_name).each do |information|
      category_node.add_information(information)
    end
  end

  articles.each do |article|
    next if !article.regular?
    name = article.name
    ac = $article_candidates[name]
    next if ac.nil?
    ac = Yajl::Parser.parse(ac)
    node = Node.new(name)
    category_node.add_relation(Relation.new('article', node))

    build_information_nodes(ac, name).each do |information|
      node.add_information(information)
    end
  end

  parents.each do |category|
    next if !category.regular? || !category.plural?
    name = category.name
    ac = $category_candidates[name]
    next if ac.nil?
    ac = Yajl::Parser.parse(ac)
    node = Node.new(name)
    category_node.add_relation(Relation.new('parent', node))

    build_information_nodes(ac, 'Category:'+name).each do |information|
      node.add_information(information)
    end
  end

  children.each do |category|
    next if !category.regular? || !category.plural?
    name = category.name
    ac = $category_candidates[name]
    next if ac.nil?
    ac = Yajl::Parser.parse(ac)
    node = Node.new(name)
    category_node.add_relation(Relation.new('child', node))

    build_information_nodes(ac, 'Category:'+name).each do |information|
      node.add_information(information)
    end
  end

  return category_node
end

def build_graph_for_article(article_name)
  concept = Concept.find_by_name(article_name)

  categories = concept.categories


  article_node = Node.new(article_name)
  ac = $article_candidates[article_name]
  if not ac.nil?
    ac = Yajl::Parser.parse(ac)


    build_information_nodes(ac, article_name).each do |information|
      article_node.add_information(information)
    end
  end



  categories.each do |category|
    next if !category.regular? || !category.plural?
    name = category.name
    ac = $category_candidates[name]
    next if ac.nil?
    ac = Yajl::Parser.parse(ac)
    node = Node.new(name)
    article_node.add_relation(Relation.new('parent', node))

    build_information_nodes(ac, 'Category:'+name).each do |information|
      node.add_information(information)
    end
  end



  return article_node
end


def get_connected_names_for_article(article_name)
  connected = []
  concept = Concept.find_by_name(article_name)

  categories = concept.categories




  categories.each do |category|
    next if !category.regular? || !category.plural?
    name = category.name
    ac = $category_candidates[name]
    next if ac.nil?
    connected << 'Category:'+name
  end



  return connected
end

def get_connected_names_for_category(category_name)
  connected = []
  category = Category.find_by_name(category_name)
  articles = category.concepts
  parents = category.parents
  children = category.children


  articles.each do |article|
    next if !article.regular?
    name = article.name
    ac = $article_candidates[name]
    next if ac.nil?
    connected << name
  end

  parents.each do |category|
    next if !category.regular? || !category.plural?
    name = category.name
    ac = $category_candidates[name]
    next if ac.nil?
    connected << 'Category:'+name
  end

  children.each do |category|
    next if !category.regular? || !category.plural?
    name = category.name
    ac = $category_candidates[name]
    next if ac.nil?
    connected << 'Category:'+name
  end

  return connected
end