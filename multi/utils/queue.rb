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
require 'pqueue'
require 'priority_queue'
require 'fc'
require './utils/graph_libs.rb'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -m reference.csv -i classification.csv -s [s,a,n,w,ma,cm]\n" +
             "Generates all phrases for denotation mapping."
  on :h=, :host, "Cyc host", default: 'localhost'
  on :p=, :port, "Cyc port", as: Integer, default: 3601
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

cyc = Cyc::Client.new(cache: true, host: options[:host], port: options[:port])
name_service = Mapping::Service::CycNameService.new(cyc)

include Rlp::Wiki
Database.instance.open_database(options[:database] || '../../en-2013/')

$category_candidates = DBM.open('category_candidate')
$article_candidates = DBM.open('joined')


#TODO infer categories, e.g. Boston Bruins players

recalculate = DBM.open('recalcualte')
recalculate.each_key do |key|
  recalculate[key]='X'
end
#TODO change everything to X

$assigned = DBM.open('assigned3')
q = FastContainers::PriorityQueue.new(:max)

CSV.open('results.csv') do |input|
  input.with_progress do |row|
    name, information_name, cyc_id, cyc_name, max_value, count, value = row
    # pq.push([value, row])
    next if !$assigned[[name, information_name].to_s].nil?
    q.push([name, information_name, cyc_id], value.to_f)
  end
end

CSV.open('results2.csv') do |input|
  input.with_progress do |row|
    name, information_name, cyc_id, cyc_name, max_value, count, value = row
    # pq.push([value, row])
    next if !$assigned[[name, information_name].to_s].nil?
    q.push([name, information_name, cyc_id], value.to_f)
  end
end

CSV.open('results_multi2.csv', 'a') do |output|
  Progress.start(q.size)
  while !q.empty? do

    name, information_name, cyc_id = q.top
    value = q.top_key
    q.pop



    #sprawdz czy trzeba przeliczyc
    recalulate_value = recalculate[[name, information_name].to_s]


    if recalulate_value.nil?

    elsif recalulate_value=='X'
      # recalculate and next
      if name.start_with?('Category:')
        node=build_graph_for_category(name[9..-1])
      else
        node=build_graph_for_article(name)
      end
      node.score_informations(name_service)

      # p ['recalculated', name]
      node.information_nodes.each do |information_node|
        # next if information_name!=information_node.name
        # cyc_name = information_node.best_candidate.cyc_term(name_service).to_ruby.to_s
        # output << ['Category:'+node.name, information_node.name, information_node.best_candidate.cyc_id, cyc_name, information_node.best_candidate.score.max_value,  information_node.best_candidate.score.count,  information_node.best_candidate.score.value]
        if !information_node.assigned_type.nil?
          next
        end
        q.push([name, information_node.name, information_node.best_candidate.cyc_id], information_node.best_candidate.score.value)
        recalculate[[name, information_node.name].to_s] = information_node.best_candidate.score.value
      end

      #usun z recalc
      next
    elsif recalulate_value.to_f!=value
      next
    end

    Progress.step
    $assigned[[name, information_name].to_s]= cyc_id
    recalculate.delete([name, information_name].to_s)

    #TODO mark nodes for recalc
    output << [name, information_name, cyc_id, value]

    if name.start_with?('Category:')
      node=build_graph_for_category(name[9..-1])
    else
      node=build_graph_for_article(name)
    end



    node.relations.each do |relation|
      relation.node.information_nodes.each do |information_node|
        next if !information_node.assigned_type.nil?
        recalculate[[relation.node.name, information_node.name].to_s]='X'
      end
    end
  end
end


#TODO category names prefixed
#TODO parallel
#TODO jak ujednolicic score dla kategorii i artykulow?
#TODO jezeli min nie potrzebne to nieliczyc - znacznie przypspieszy


# posortowac wezly
# przypisac i przekalkulowac zalezne
# PRZYPISANIE może tylko zmneijszać wynik, wiec zamiast kalkulacji oznaczyc jako do przeliczenia
#napotykając węzeł do przeliczenia trzeba zaktualizować i wrzucić w odpowiednie meijsce kolejki

#posortowac external
#zrobic kolejke na aktualizacje
#czytac z powyzszych dwoch zrodel
#pominac mneijsze od 0?

# wydaje sie, ze przypisanie typuob cos psuj
# Category:British diplomats,name,Mx8Ngx4rwEcGC5wpEbGdrcN5Y29ycB4rvVj_jpwpEbGdrcN5Y29ycB4rv5VvH5wpEbGdrcN5Y29ycA,1242864.000000005
# Category:British diplomats,head0,Mx8Ngx4rwEcGC5wpEbGdrcN5Y29ycB4rvVj_jpwpEbGdrcN5Y29ycB4rv5VvH5wpEbGdrcN5Y29ycA,1240587.800000005

