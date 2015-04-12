#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'progress'
require 'csv'
require 'slop'
require 'cycr'
require 'set'
require 'colors'

$:.unshift '../category-mapping/lib'
require 'mapping/cyc_term'
require 'mapping/service/cyc_name_service'
require 'mapping/bidirectional_map'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -m reference.csv -i classification.csv\n" +
             'Counts precision, recall and F1 measure for the classification results.'

  on :m=, :verification, 'Manual verification', required: true
  on :i=, :classification, 'Automatic articles classification', required: true
  on :h=, :host, 'Cyc host (localhost)', default: 'localhost'
  on :p=, :port, 'Cyc port (3601)', as: Integer, default: 3601
  on :d, :debug, 'Turn on debugging'
  on :x=, :mismatch, 'File with algorithm errors (CSV)'
  on :t=, :trace, 'File with trace for each article (CSV)'
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

cyc = Cyc::Client.new(host: options[:host], port: options[:port], cache: true)
name_service = Mapping::Service::CycNameService.new(cyc)

verification = Hash.new { |h, e| h[e] = [] }

CSV.open(options[:verification], "r:utf-8") do |verification_csv|
  verification_csv.with_progress do |name, cycid, cycterm, decision|
    term = name_service.find_by_id(cycid)
    next if term.nil?
    decision = (decision == 'true')
    verification[name] << [term, decision]
  end
end


def precision_recall_permissive(verifications, terms, cyc)
  results = []

  terms.each do |algorithm_output|
    verifications.each do |verification_output, valid|
      if algorithm_output == verification_output
        results.push([true, valid]) # TP/FP
      elsif valid
        if cyc.genls?(algorithm_output, verification_output) || cyc.isa?(algorithm_output, verification_output)
          results.push([true, true]) # TP
        elsif cyc.disjoint_with?(verification_output, algorithm_output)
          results.push([false, true]) # FN
        end
      else
        if cyc.genls?(algorithm_output, verification_output) || cyc.isa?(algorithm_output, verification_output)
          results.push([true, false]) # FP
        elsif cyc.disjoint_with?(verification_output, algorithm_output)
          results.push([false, false]) # TN
        end
      end
    end
  end
  return results
end

def precision_recall_restrictive(verifications, terms, cyc, name)
  results = []

  terms.each do |algorithm_output|
    verifications.each do |verification_output, valid|
      if algorithm_output == verification_output
        results.push([true, valid]) # TP/FP
      elsif valid
        if cyc.disjoint_with?(verification_output, algorithm_output)
          results.push([false, true]) # FN
        end
      else
        if cyc.genls?(algorithm_output, verification_output) || cyc.isa?(algorithm_output, verification_output)
          results.push([true, false]) # FP
        end
      end
    end
  end
  return results
end

def print_validation(name,expected_term,algorithm_terms,expected_value,algorith_value)
  if expected_value == algorith_value
    title = 'True positive or true negative'
    rationale = 'is/is not included in'
    color = :green
  elsif expected_value && !algorith_value
    title = 'False negative'
    rationale = 'should BE included in'
    color = :yellow
  elsif !expected_value && algorith_value
    title = 'False positive'
    rationale = 'should NOT BE included in'
    color = :red
  end
  return unless color == :red
  puts "#{title} for '#{name}'".hl(color)
  puts "- #{expected_term.to_ruby}"
  puts rationale
  algorithm_terms.each do |term|
    puts "- #{term.to_ruby}"
  end
end

def precision_recall_neutral(verifications, terms, debug, name, mismatch_file)
  results = []
  terms = Set.new(terms)
  verifications.each do |verification_output, valid|
    if terms.include? verification_output
      results.push([true, valid]) # XP
      if debug
        print_validation(name,verification_output,terms,valid,true)
      end
      if mismatch_file && !valid
        mismatch_file << [name,verification_output.id,verification_output.to_ruby, "FP"]
      end
    else
      results.push([false, valid]) # XN
      if debug
        print_validation(name,verification_output,terms,valid,false)
      end
      if mismatch_file && valid
        mismatch_file << [name,verification_output.id,verification_output.to_ruby, "FN"]
      end
    end
  end
  return results
end

def cumulate(results, stats=nil)
  stats ||= Hash.new(0)
  results.each do |algorithm_status, verification_status|
    if algorithm_status
      if verification_status
        stats[:true_positives] += 1
      else
        stats[:false_positives] += 1
      end
    else
      if verification_status
        stats[:false_negatives] += 1
      else
        stats[:true_negatives] += 1
      end
    end
  end
  stats
end

def print_precision_recall(stats)
  #p stats

  precision = stats[:true_positives] / (stats[:true_positives] + stats[:false_positives]).to_f
  recall = stats[:true_positives] /(stats[:true_positives] + stats[:false_negatives]).to_f
  f1 = 2 * precision * recall / (precision + recall)
  #puts "Positive precision/recall/f1 %.3f %.3f %.3f " % [precision, recall, f1]

  article_precision =stats[:sum_precision]/stats[:count_preciscion]
  article_recall = stats[:sum_recall]/stats[:count_recall]
  article_f1 = 2 * article_precision * article_recall / (article_precision + article_recall)
  #puts "Article-wise precision/recall %.3f %.3f" % [article_precision, article_recall]

  return [precision, recall, f1, article_precision, article_recall, article_f1]
end

def article_wise(article_stats, cumulative_stats)
  precision = article_stats[:true_positives] / (article_stats[:true_positives] + article_stats[:false_positives]).to_f
  recall = article_stats[:true_positives] /(article_stats[:true_positives] + article_stats[:false_negatives]).to_f


  if not precision.nan?
    cumulative_stats[:sum_precision]+=precision
    cumulative_stats[:count_preciscion] += 1
  end
  if not recall.nan?
    cumulative_stats[:sum_recall]+=recall
    cumulative_stats[:count_recall] += 1
  end

end

stats = Hash.new { |h, e| h[e] = Hash.new(0) }

verified = Set.new
trace = {}

mismatch_file = CSV.open(options[:mismatch],"w") if options[:mismatch]
trace_file = CSV.open(options[:trace],"w") if options[:trace]
CSV.open(options[:classification],"r:utf-8") do |articles_csv|
  if options[:debug]
    method = articles_csv.method(:each)
  else
    method = articles_csv.method(:with_progress)
  end
  method.call do |name, *cycids|
    next if name.nil? # TODO?
    name.gsub!('_', ' ')
    next if !verification.include? name
    verified.add name
    break if verified.size == verification.size

    verifications = verification[name]
    terms = []
    cycids.each_slice(2) { |id, name| terms << name_service.find_by_id(id) }

    results = precision_recall_neutral(verifications, terms, options[:debug], name, mismatch_file)
    cumulate(results, stats[:neutral])
    article_stats = cumulate(results)
    article_wise(article_stats, stats[:neutral])

    results = precision_recall_permissive(verifications, terms, cyc)
    if trace_file
      if results.size > 0
        trace[name] = results.inject(0){|s,(v1,v2)| s + (v1 == v2 ? 1 : 0 ) }/results.size.to_f
      end
    end
    cumulate(results, stats[:permissive])
    article_stats = cumulate(results)
    article_wise(article_stats, stats[:permissive])

    results = precision_recall_restrictive(verifications, terms, cyc, name)
    cumulate(results, stats[:restrictive])
    article_stats = cumulate(results)
    article_wise(article_stats, stats[:restrictive])
    break if verified.size == verification.size
  end
end
mismatch_file.close if mismatch_file

if trace_file
  verification.each do |name,terms|
    if trace[name]
      trace_file << [trace[name]]
    else
      trace_file << [0.0]
    end
  end
  trace_file.close
end


# p Set.new(verification.keys)-verified

neutral = print_precision_recall(stats[:neutral])
permissive = print_precision_recall(stats[:permissive])
restrictive = print_precision_recall(stats[:restrictive])
=begin
puts "\nNeutral:"
puts "\nPermissive:"
puts "\nRestrictive:"
=end
puts "\nCoverage: #{verified.size}/#{verification.size} %.1f%%\n" % (verified.size * 100 / verification.size.to_f)
puts


puts '| %-25s | Neutral | Permissive | Restrictive |' % " "
puts '| %-25s | ------- | ---------- | ----------- |' % ("-" * 25)
['Precision', 'Recall', 'F1', 'Article-wise precision', 'Article-wise recall', 'Article-wise F1'].each.with_index do |measure, index|
  puts '| %-25s | %7.3f | %10.3f | %11.3f |' % [measure, neutral[index], permissive[index], restrictive[index]]
end

3.times do |index|
  print ' %.1f & %.1f & %.1f &' % [neutral[index] * 100, permissive[index] * 100, restrictive[index] * 100]
end

puts
precision = permissive[1] * 100
recall = permissive[4] * 100 * verified.size / verification.size.to_f
f1 = 2 * precision * recall / (precision + recall)
puts "Tipalo P/R/F: | %.1f |  %.1f |  %.1f |" % [precision,recall,f1]
