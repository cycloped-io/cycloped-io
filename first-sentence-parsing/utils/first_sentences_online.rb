#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
require 'slop'
require 'csv'
require 'progress'
require 'colors'
require 'cycr'
require 'set'
require 'open-uri'
require 'nokogiri'
require 'typhoeus'
$:.unshift 'lib'

include URI::Escape

def wiki_uri(article_name, namespace)
  "http://#{namespace}.wikipedia.org/wiki/#{encode(article_name.tr(' ', '_'))}"
end

def get_abstract(body)
  doc = Nokogiri.HTML(body)
  nodes = doc.css('#mw-content-text > p')
  nodes.each do |node|
    return node.inner_text
  end
end

options = Slop.new do
  banner "#{$PROGRAM_NAME} -i articles.csv -o first_paragraphs.csv\n" +
             'Get first paragraphs for articles'

  on :i=, :input, 'Input file with articles names to download', required: true
  on :o=, :output, 'Output file with first paragraphs', required: true
  on :w=, :wikipedia, 'Wikipedia language version', default: 'en'
  on :b=, :batch_size, 'Batch size', default: 1000, as: Integer
end

begin
  options.parse
rescue Exception => ex
  puts ex
  puts options
  exit
end


articles = []
CSV.open(options[:input], 'r:utf-8') do |input|
  input.with_progress do |row|
    articles << row.first
  end
end

BATCH_SIZE=options[:batch_size]
namespace=options[:wikipedia]

CSV.open(options[:output], 'w:utf-8') do |output|
  hydra = Typhoeus::Hydra.new(max_concurrency: 20)
  articles.each_slice(BATCH_SIZE).with_progress do |articles_batch|
    requests = []
    articles_batch.each do |article_name|
      request = Typhoeus::Request.new(wiki_uri(article_name, namespace), followlocation: true)
      requests << [article_name, request]
      hydra.queue request
    end
    hydra.run
    requests.each do |concept_name, request|
      output << [concept_name, get_abstract(request.response.body)]
    end
  end
end
