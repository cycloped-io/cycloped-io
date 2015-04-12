#!/usr/bin/env ruby

require 'bundler/setup'

require 'rdf'
require 'sparql/client'
require 'slop'
require 'csv'
require 'progress'
require 'cycr'
$:.unshift "../category-mapping/lib"
require 'mapping/service/cyc_name_service'
require 'mapping/cyc_term'


options = Slop.new do
  banner "#{$PROGRAM_NAME} -f matches.csv -c constraints.csv -o filtered_matches.csv [-p port] [-h host] [-v]\n" +
    "Discover statistics of constraints for particular predicate or pattern"

  on :f=, :input, "Simple pattern DBpedia predicate matches (CSV)", required: true
  on :o=, :output, "Output file with constraints stats (CSV)", required: true
  on :p=, :port, "Port of Virtuoso server with DBpedia", as: Integer, default: 8890
  on :h=, :host, "Host of Virtuoso server with DBpedia", default: "localhost"
  on :P=, :cyc_port, "Cyc port", as: Integer, default: 3601
  on :H=, :cyc_host, "Cyc host", default: "localhost"
  on :v, :verbose, "Verbose output"
  on :m, :mode, "Mode: p - Predicates, t - paTterns", required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

QUERY = "select * from <http://best.opencyc.org> where {<http://dbpedia.org/resource/%s> a ?type}"
def type(name,client)
  name = CGI.escape(name.gsub(" ","_"))
  query = QUERY % [name]
  client.query(query).map{|r| r.type.to_s }.first
rescue
  nil
end

cyc = Cyc::Client.new(host: options[:cyc_host],port: options[:cyc_port], cache: true)
name_service = Mapping::Service::CycNameService.new(cyc)
client = SPARQL::Client.new("http://#{options[:host]}:#{options[:port]}/sparql")
Progress.start(`wc -l #{options[:input]}`.to_i)
histogram = Hash.new{|h,e| h[e] = Hash.new(0) }
mode = options[:mode] == "p" ? :predicate : :pattern


CSV.open(options[:input]) do |input|
  input.each do |row|
    begin
      Progress.step(1)
      sleep(0.01) if options[:verbose]
      pattern,predicate,category_name,subject_name,object_name = row
      subject_type = type(subject_name,client)
      next if subject_type.nil?
      object_type = type(object_name,client)
      next if object_type.nil?
      subject_type_id = subject_type[subject_type.rindex("/")+1..-1]
      object_type_id = object_type[object_type.rindex("/")+1..-1]

      predicate_name = predicate[predicate.rindex("/")+1..-1] if mode == :predicate
      subject_term = name_service.find_by_id(subject_type_id)
      object_term = name_service.find_by_id(object_type_id)
      if mode == :predicate
        entity = predicate_name
      else
        entity = pattern
      end
      if options[:verbose]
        puts "#{pattern},#{entity},#{subject_name},#{object_name}"
        puts "#{subject_term.to_ruby} #{object_term.to_ruby}"
      end
      histogram[entity][[subject_term,object_term]] += 1
    rescue Interrupt
      puts
      break
    rescue Exception => ex
      puts ex
      puts row
      puts ex.backtrace[0...3]
    end
  end
end
CSV.open(options[:output],"w") do |output|
  histogram.sort_by{|k,v| k }.each do |entity,stats|
    stats.sort_by{|k,v| -v }.each do |(term1,term2),count|
      output << [entity,term1.id,term1.to_ruby,term2.id,term2.to_ruby,count]
    end
  end
end
Progress.stop
