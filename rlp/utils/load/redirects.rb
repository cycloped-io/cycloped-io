#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'slop'
require 'rlp/wiki'
require 'progress'
require 'csv'
include Rlp::Wiki

# Script for loading redirects.

opts = Slop.new do
  banner "Usage: #{$PROGRAM_NAME} -d db_path -w data_path\n" +
    "Load links between redirects, articles and categories"

  on 'd', 'db_path', 'Database path', argument: :mandatory, required: true
  on 'w', 'data_path', 'WikiMiner files path', argument: :mandatory, required: true
end
begin
  opts.parse
rescue Slop::MissingOptionError
  puts opts
  exit
end

db_path = opts[:db_path]
data_path = opts[:data_path]

total = 0
linked = 0
total_pages = 0
linked_pages = 0
Database.instance.open_database(db_path,:readonly => false)
Progress.start(`wc -l #{opts[:data_path]}/redirectSourcesByTarget.csv`.to_i)
CSV.open("#{data_path}/redirectSourcesByTarget.csv","r:utf-8") do |input|
  input.each do |name,type,*redirects|
    Progress.step(1)
    next if name.nil?
    total_pages += 1
    begin
      case type
      when "0"
        page = Concept.find_by_name(name)
      when "1"
        page = Category.find_by_name(name)
      end
      next if page.nil?
      linked_pages += 1
      redirects.each do |redirect_id|
        redirect = Redirect.find_by_wiki_id(redirect_id.to_i)
        total += 1
        next if redirect.nil?
        next if redirect.page

        # Link concept with its redirect.
        page.redirects << redirect
        redirect.page = page
        redirect.store
        linked += 1
      end
      page.store
    rescue Interrupt
      puts
      break
    rescue Exception => ex
      puts "error #{name}"
      puts ex
      puts ex.backtrace[5]
    end
  end
end
Database.instance.close_database
Progress.stop
puts "Linked redirects: #{linked}/#{total}"
puts "Linked pages: #{linked_pages}/#{total_pages}"
