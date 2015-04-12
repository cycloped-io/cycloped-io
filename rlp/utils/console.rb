#!/usr/bin/env ruby
# encding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
require 'irb'
require 'progress'

include Rlp::Wiki

at_exit do
  Database.instance.open_database(ARGV[0])
  if ENV['RLP_WIKI_PAGES']
    Page.path = ENV['RLP_WIKI_PAGES']
  end
  ARGV.clear
  IRB.start
  Database.instance.close_database
end
