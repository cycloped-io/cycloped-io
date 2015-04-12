#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
$:.unshift 'lib'
$:.unshift '../category-mapping/lib'
require 'slop'
require 'csv'
require 'cycr'
require 'progress'
require 'mapping'


options = Slop.new do
  banner '#{$PROGRAM_NAME} -f terms.csv -o instances.csv -t term [-h host] [-p port]\n' +
    'Select instances of specified term from the file with Cyc terms'

  on :f=, :input, 'File with Cyc terms: id, name', required: true
  on :o=, :output, 'File with Cyc collections', required: true
  on :t=, :term, 'Term whose instances are selected', default: :Collection, as: Symbol
  on :h=, :host, 'Cyc host (localhost)', default: 'localhost'
  on :p=, :port, 'Cyc port (3601)', as: Integer, default: 3601
end

begin
  options.parse
rescue Exception
  puts options
  exit
end


cyc = Cyc::Client.new(host: options[:host], port: options[:port], cache: true)
name_service = Mapping::Service::CycNameService.new(cyc)

CSV.open(options[:input],"r:utf-8") do |input|
  CSV.open(options[:output],"w") do |output|
    begin
      input.with_progress do |id,name|
        term = name_service.find_by_id(id)
        if term.nil?
          puts "Missing term #{id} #{name}"
          next
        end
        if cyc.with_any_mt{|c| c.isa?(term,options[:term]) }
          output << [id,name]
        end
      end
    rescue Interrupt
      # interrupt gracefully
    end
  end
end
