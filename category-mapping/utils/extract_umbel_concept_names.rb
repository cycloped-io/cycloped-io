#!/usr/bin/env ruby

require 'slop'
require 'rdf'
require 'rdf/n3'
require 'csv'

class ReferenceConcept
  attr_accessor :name, :label, :parents

  def initialize(name)
    @name = name
    @label = ""
    @parents = []
  end

  def to_a
    [self.name, self.label, *self.parents]
  end

  def to_s
    "%-30s %-30s %s" % [self.name, self.label, self.parents.join(",")]
  end
end


options = Slop.new do
  banner "#{$PROGRAM_NAME} -f reference_concepts.n3 [-o names.csv]\n" +
             "Extract names of all reference concepts with their prefered labels from UMBEL n3 file"

  on :f=, :input, "File with descriptions of reference Umbel concepts (n3)", required: true
  on :o=, :output, "File where extracted names and labels are stored (optional)"
end

begin
  options.parse
rescue
  puts options
  exit
end

names = {}
RDF::N3::Reader.open(options[:input]) do |reader|
  reader.each_statement do |statement|
    subject = statement.subject.to_s
    next if subject !~ /^http:/
    subject = subject[subject.rindex("/")+1..-1]
    next if subject !~ /^[A-Z]/
    next if subject =~ /#/
    unless names[subject]
      names[subject] = ReferenceConcept.new(subject)
    end
    if statement.predicate.to_s =~ /prefLabel$/
      names[subject].label = statement.object.to_s
    end
    if statement.predicate.to_s =~ /subClassOf$/
      next unless statement.object.to_s =~ /http:/
      parent = statement.object.to_s
      parent = parent[parent.rindex("/")+1..-1]
      names[subject].parents << parent
    end
  end
end

if options[:output]
  CSV.open(options[:output], "w") do |output|
    names.each do |name, reference_concept|
      output << reference_concept.to_a
    end
  end
else
  names.each do |name, reference_concept|
    puts reference_concept
  end
end
