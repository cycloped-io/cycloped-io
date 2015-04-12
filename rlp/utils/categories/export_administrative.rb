#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'slop'
require 'rlp/wiki'
require 'csv'
require 'progress'

opts = Slop.new do
  banner "Usage: #{$PROGRAM_NAME} -d data_dir -o output_dir \nExport administrative and stub categories to CSV file."

  on :d=, 'db_path', 'ROD Database path', required: true
  on :o=, 'output_path', 'Output directory where administrative.csv and stubs.csv files will be saved', required: true
end
begin
  opts.parse
rescue Slop::MissingOptionError
  puts opts
  exit
end

db_path = opts[:db_path]
output_path = opts[:output_path]

include Rlp::Wiki

Database.instance.open_database(db_path)


CSV.open(output_path + "/administrative.csv", "w") do |administrative|
  CSV.open(output_path + "/stubs.csv", "w") do |stubs|
    CSV.open(output_path + "/non_administrative.csv", "w") do |non_administrative|
      Category.with_progress do |category|
        if category.administrative?
          administrative << [category.name]
        elsif category.stub?
          stubs << [category.name]
        else
          non_administrative << [category.name]
        end
      end
    end
  end
end


Database.instance.close_database
