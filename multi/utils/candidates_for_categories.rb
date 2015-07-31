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

options = Slop.new do
  banner "#{$PROGRAM_NAME} \n" +
             "Assign candidates to categories."

  on :h=, :host, "Cyc host", default: 'localhost'
  on :p=, :port, "Cyc port", as: Integer, default: 3601
  on :c=, :"category-filters", "Filters for categories: c - collection, s - most specific,\n" +
            "n - noun, r - rewrite of, l - lower case, f - function, c|i - collection or individual, b - black list", default: 'c:r:f:l:d'
  on :g=, :"genus-filters", "Filters for genus proximum types: (as above)", default: 'c:r:f:l:d'
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

# cyc = Cyc::Client.new(cache: true, host: options[:host], port: options[:port])
# name_service = Mapping::Service::CycNameService.new(cyc)
#
# Thing = name_service.find_by_term_name('Thing')
#
# black_list_reader = Mapping::BlackListReader.new(options[:"black-list"])
# name_service = Mapping::Service::CycNameService.new(cyc)
# filter_factory = Mapping::Filter::Factory.new(cyc: cyc, black_list: black_list_reader.read)
# term_provider = Mapping::TermProvider.
#     new(cyc: cyc, name_service: name_service,
#         category_filters: filter_factory.filters(options[:"category-filters"]),
#         genus_filters: filter_factory.filters(options[:"genus-filters"]))
#

@nouns = Nouns.new



def singularize_name_nouns(name, head)
  names = [name]
  singularized_heads = @nouns.singularize(head)
  if not singularized_heads.nil?
    singularized_heads.each do |singularized_head|
      names << name.sub(/\b#{Regexp.quote(head)}\b/, singularized_head)
    end
  end
  names
end

cyc = Cyc::Client.new(cache: true, host: options[:host], port: options[:port])
name_service = Mapping::Service::CycNameService.new(cyc)

Thing = name_service.find_by_term_name('Thing')

black_list_reader = Mapping::BlackListReader.new(options[:"black-list"])
name_service = Mapping::Service::CycNameService.new(cyc)
filter_factory = Mapping::Filter::Factory.new(cyc: cyc, black_list: black_list_reader.read)
term_provider = Mapping::TermProvider.
    new(cyc: cyc, name_service: name_service,
        category_filters: filter_factory.filters(options[:"category-filters"]),
        genus_filters: filter_factory.filters(options[:"genus-filters"]))

filters = filter_factory.filters(options[:"genus-filters"])

include Rlp::Wiki
Database.instance.open_database(options[:database] || '../../en-2013/')



def read_phrase_candidates
  phrase_candidates = {}
  CSV.open('phrase_candidates.csv') do |input|
    input.with_progress do |phrase, *candidates|
      phrase_candidates[phrase] = candidates.each_slice(2).to_a
    end
  end
  return phrase_candidates
end

phrase_candidates = AutoSerializer.auto(:read_phrase_candidates)

simplifier = Syntax::Stanford::Simplifier

def uncapitalize(s)
  return nil if s.nil?
  s[0, 1].downcase + s[1..-1]
end

last_name=nil
CSV.open('category_candidatesc.csv') do |input|
  input.with_progress do |row|
    last_name=row.first
  end
end

p last_name
# utworzyc loalna reprezentacje grafowa i na tym metryki
omit=true
CSV.open('category_candidatesc.csv', 'a') do |output|
  Category.with_progress do |category|
    #TODO only regular?

    if last_name.nil?
      omit = false
    elsif category.name==last_name
      omit=false
      next
    end
    next if omit


    # begin
    singulars=(singularize_name_nouns(category.name, category.head)+singularize_name_nouns(uncapitalize(category.name), uncapitalize(category.head))).uniq

    tuple = {}
    tuple['name']={}
    singulars.each do |singular|
      candidates = phrase_candidates[singular]
      if candidates.nil?
        candidates = term_provider.candidates_for_name(singular, filters).map { |candidate| [candidate.id,candidate.name] }
      end
      tuple['name'][singular] = candidates
    end

    category.head_trees.each_with_index do |tree, tree_index|
      names = simplifier.new(tree).simplify.to_a

      names_candidates = {}

      head_node = tree.find_head_noun
      if head_node
        head = head_node.content
        names.each do |name|
          simplified_names = (singularize_name_nouns(name, head) + singularize_name_nouns(uncapitalize(name), uncapitalize(head))).uniq
          simplified_names.each do |simplified_name|
            candidates = phrase_candidates[simplified_name]
            if candidates.nil?
              p simplified_name
              next
            end
            if !candidates.empty?
              names_candidates[simplified_name]= candidates
            end
          end
        end
        tuple['head'+tree_index.to_s]=names_candidates if !names_candidates.empty?
      else
        p category.name, tree.to_s
      end


    end
    output << [category.name, Yajl::Encoder.encode(tuple)]
  end
end

