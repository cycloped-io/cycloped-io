#!/usr/bin/env ruby

require 'bundler/setup'
$:.unshift "lib"
require 'slop'
require 'progress'
require 'rlp/wiki'
require 'compound/proper_name_extractor'
require 'compound/proper_name_finder'
require 'csv'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -d database -o mapping.csv\n"+
    "Find Wikipedia article names in category names."

  on :d=, :database, "ROD Wikipedia database", required: true
  on :o=, :output, "Output file", required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

include Rlp::Wiki

extractor = Compound::ProperNameExtractor.new
finder = Compound::ProperNameFinder.new(Concept,extractor)

Database.instance.open_database(options[:database])
Progress.start(Category.count)
CSV.open(options[:output],"a") do |output|
  Category.each.with_index do |category,index|
    Progress.step(1)
    begin
      row = [category.wiki_id,category.name]
      #next unless category.regular?
      matches = finder.find(category.name)
      matches.each do |concept,name,range|
        category.name.scan(name) do |match|
          row.concat([$`,concept.name,$'])
        end
      end
      category.name.scan(/\d+/) do |match|
        row.concat([$`,match,$'])
      end
      output << row
    rescue Interrupt
      puts
      break
    rescue Exception => ex
      puts "Error for #{category}"
      puts ex
      puts ex.backtrace[0..5]
    end
  end
end
Progress.stop
Database.instance.close_database
