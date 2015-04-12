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
  banner '#{$PROGRAM_NAME} -f terms.csv -o specs.csv -t term [-h host] [-p port]\n' +
    'Select specs or instances of the term from the file with Cyc terms'

  on :f=, :input, 'File with Cyc terms: id, name', required: true
  on :o=, :output, 'File with specs', required: true
  on :r=, :rest, 'File with the remainin terms', required: true
  on :t=, :term, 'Term whose specs are selected', required: true, as: Symbol
  on :h=, :host, 'Cyc host (localhost)', default: 'localhost'
  on :p=, :port, 'Cyc port (3601)', as: Integer, default: 3601
  on :m=, :mode, 'Select: s - specs, i - instances, m - min specs', default: 's'
end

begin
  options.parse
rescue Exception
  puts options
  exit
end

method =
  if options[:mode] == 's'
    :genls?
  else
    :isa?
  end

cyc = Cyc::Client.new(host: options[:host], port: options[:port], cache: true)
name_service = Mapping::Service::CycNameService.new(cyc)


selected = 0
unselected = 0
CSV.open(options[:input],"r:utf-8") do |input|
  CSV.open(options[:output],"w") do |output|
    CSV.open(options[:rest],"w") do |rest|
      begin
        input.with_progress do |id,name|
          term = name_service.find_by_id(id)
          if term.nil?
            puts "Missing term #{id} #{name}"
            next
          end
          result = false
          if options[:mode] == 'm'
            result = (cyc.with_any_mt{|c| c.min_genls(term) } || []).include?(options[:term])
          else
            result = cyc.with_any_mt{|c| c.send(method,term,options[:term]) }
          end
          if result
            output << [id,name]
            selected += 1
          else
            rest << [id,name]
            unselected += 1
          end
        end
      rescue Interrupt
        # interrupt gracefully
      end
    end
  end
end
puts "Selected/unselected #{selected}/#{unselected}/#{(selected/(selected + unselected).to_f * 100).round(1)}%"
