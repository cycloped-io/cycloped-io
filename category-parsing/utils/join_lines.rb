#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'progress'
require 'csv'


type1 = 'normal'
type2 = 'normal'

if ARGV.size == 3
  path1 = ARGV[0]
  path2 = ARGV[1]
  out = ARGV[2]
elsif ARGV.size == 5
  type1 = ARGV[0]
  path1 = ARGV[1]
  type2 = ARGV[2]
  path2 = ARGV[3]
  out = ARGV[4]
else
  exit
end

if type1=='normal'
  file1 = File.open(path1, "r:utf-8")
elsif type1=='csv'
  file1 = CSV.open(path1, 'r:utf-8')
end

if type2=='normal'
  file2 = File.open(path2, "r:utf-8")
elsif type2=='csv'
  file2 = CSV.open(path2, 'r:utf-8')
end

CSV.open(out, "w:utf-8") do |csv|
  while true do
    begin
      s1 = file1.readline
      if s1.respond_to?(:strip)
        s1.strip!
      end
      s2 = file2.readline
      if s2.respond_to?(:strip)
        s2.strip!
      end
    rescue EOFError
      break
    end

    if s1==nil or s2==nil
      break
    end
    c = []
    c.push s1
    c.push s2
    c.flatten!
    csv << c
  end
end
