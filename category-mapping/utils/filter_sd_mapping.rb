require 'bundler/setup'
require 'rlp/wiki'
require 'cycr'
require 'csv'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f input.csv -o output.csv [-d database]\n" +
    "Removes SD mapping to Wikipedia categories not in plural form."

  on :f=, :input, "Input file with the mapping", required: true
  on :o=, :output, "Output file with filtered mapping", required: true
  on :d=, :database, "ROD database", default: "../rlp/data/en-2013"
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

plural_categories = CSV.open(options[:output], 'w')

f=CSV.open(options[:input])
f.each do |row|
  wiki=row[0]
  puts wiki
  category = Category.find_by_name(wiki)
  next if category.nil?
  next unless category.regular?
  next unless category.plural?
  plural_categories << row
end

f.close
plural_categories.close
