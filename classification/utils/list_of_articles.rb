#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'rlp/wiki'
$:.unshift 'lib'
require 'slop'
require 'csv'
require 'cycr'
require 'progress'
require 'benchmark'
require 'nokogiri'
require 'wikicloth'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -o lists.csv -d rod -p pages-articles.xml\n" +
             'Get list with articles'

  on :o=, :output, 'Output file', required: true
  on :d=, :database, 'ROD database', required: true
  on :p=, :pages, 'pages-articles.xml', required: true
end

begin
  options.parse
rescue Exception => ex
  puts ex
  puts options
  exit
end

class WikiCloth::WikiBuffer::Table
  def to_html
    row_count = 0
    ret = "<table" + (params[0].blank? ? "" : " #{params[0].strip}") + ">"
    ret += "<caption" + (self.table_caption_attributes.blank? ? "" : " #{table_caption_attributes.strip}") +
        ">#{table_caption.strip}</caption>" unless self.table_caption.blank?
    raw_rows = []
    for row in rows
      row_count += 1
      unless row.empty?
        ret += "<tr" + (params[row_count].nil? || params[row_count].blank? ? "" : " #{params[row_count].strip}") + ">"
        raw_rows << row.map { |cell| cell[:value] }
        for cell in row
          cell_attributes = cell[:style].blank? ? "" : parse_attributes(cell[:style].strip).collect { |k, v| "#{k}=\"#{v}\"" }.join(" ")
          cell_attributes = cell_attributes.blank? ? "" : " #{cell_attributes}"
          ret += "<#{cell[:type]}#{cell_attributes}>\n#{cell[:value].strip}\n</#{cell[:type]}>"
        end
        ret += "</tr>"
      end
    end
    if @options.include? :rows
      @options[:rows] += raw_rows
    else
      @options[:rows] = raw_rows
    end

    ret += "</table>"
  end
end

def get_link(data)
  Nokogiri::HTML(data).css("a").each do |link|
    if (href = link.attr("href")) && !href.start_with?('#')
      return href
    end
  end
  return nil
end


def get_articles(data)
  wiki = WikiCloth::WikiCloth.new({:data => data})
  wiki.to_html

  rows = wiki.options[:rows]
  return [] if rows.nil?

  articles = []
  rows.each do |row|
    row.each do |cell|
      link = get_link(cell)
      if !link.nil?
        articles << link
        break
      end
    end
  end
  articles
end


include Rlp::Wiki
Database.instance.open_database(options[:database])

Concept.path=options[:pages]

CSV.open(options[:output], 'w') do |csv_lists|
  Concept.with_progress do |concept|
    if concept.name =~ /(^L|\bl)ist of\b/
      content = concept.contents

      footers = [/==\s*External links\s*==/, /==\s*See also\s*==/]
      footers.each do |regex|
        index = content.rindex(regex)
        if not index.nil?
          content = content[0..index-1]
        end
      end

      links=content.scan(/^\*\s*\[\[([^\]]+)\]\]\S*/).map { |a| a.first }
      articles = []

      links.each do |link|
        index = link.index('|')
        if index.nil?
          articles << link
        else
          articles << link[0..index-1]
        end
      end

      articles += get_articles(content)

      csv_lists << [concept.name, *articles]
    end
  end
end