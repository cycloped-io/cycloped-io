#!/usr/bin/env ruby

require 'bundler/setup'
require 'set'
require 'slop'
require 'csv'
require 'rlp/wiki'
require 'progress'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -d db -f input.csv -o translated.csv -l language\n" +
    "Translate classification or mapping for a given language."

  on :d=, :database, "Rod database", required: true
  on :f=, :input, "Input file with articles classification or category mapping (CSV)", required: true
  on :o=, :output, "Output file with translated classification or mapping (CSV)", reuqired: true
  on :l=, :language, "Language selected for translation", required: true
  on :t=, :type, "Input file type: m - mapping, c - classification", required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

include Rlp::Wiki

Database.instance.open_database(options[:database])

total = 0
found = 0
translated = 0
CSV.open(options[:input],"r:utf-8") do |input|
  CSV.open(options[:output],"w:utf-8") do |output|
    input.with_progress do |name,*tuple|
      begin
        total += 1
        if options[:type] == "m"
          page = Category.find_by_name(name)
        else
          page = Concept.find_by_name(name)
        end
        # E.g. Michael_Jackson__1
        next if page.nil?
        found += 1
        translation = page.translations.find{|t| t.language == options[:language]}
        next if translation.nil?
        translated += 1
        value = translation.value
        if options[:type] == "m"
          value = value.sub(/^[^:]*:/,"")
        end
        output << [value,*tuple]
      rescue Interrupt
        puts
        break
      rescue Exception => ex
        puts name
        puts ex
        puts ex.backtrace[0..5]
      end
    end
  end
end
puts "Translated/found/total #{translated}/#{found}/#{total}/%.1f%%" % [translated * 100.0 / total]

Database.instance.close_database
