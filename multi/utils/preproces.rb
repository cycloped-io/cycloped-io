#!/usr/bin/env ruby
# encoding: utf-8


require 'bundler/setup'
$:.unshift '../category-mapping/lib'
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
  banner "#{$PROGRAM_NAME} -i _candidates.csv -o _candidates_preprocessed.csv \n" +
             'Preprocess category/article candidates.'

  on :i=, :input, 'Entities with assigned candidates', required: true
  on :o=, :output, 'Entities with assigned candidates', required: true

end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end



CSV.open(options[:output], 'w') do |output|
  CSV.open(options[:input]) do |input|
    input.with_progress do |name, candidates|
      a = Yajl::Parser.parse(candidates)
      newa={}
      a.each do |namespace, b|
        # next if b.empty?

        c2 = Hash.new {|hash,key| hash[key] = []}
        b.each do |phrase, c|
          c.each do |cyc_id,cyc_name|
            c2[cyc_id] << phrase
          end
        end

        c2.each do |name2,cs|
          c2[name2] = cs.uniq
        end

        newa[namespace]=c2 if !c2.empty?
      end
      output << [name, Yajl::Encoder.encode(newa)] if !newa.empty?
    end
  end
  end


