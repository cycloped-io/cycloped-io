#!/usr/bin/env ruby

require 'set'
require 'slop'
require 'cycr'
require 'csv'
require 'colors'
$:.unshift "lib"
require 'mapping/cyc_term'
require 'mapping/cyc_name_service'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -f names.csv -m mapping.csv -e missing.csv -a ambiguous.csv [-p port] [-h host]\n" +
    "Map Umbel concepts to Cyc concepts."

  on :f=, :input, "File with names and labels of Umbel concepts (CSV)", required: true
  on :m=, :mapping, "Mapping between Umbel concepts and Cyc concepts (CSV)", required: true
  on :e=, :missing, "File with names of Umbel concepts that were not found in Cyc", required: true
  on :a=, :ambiguous, "File with ambiguous mappings (CSV)", required: true
  on :p=, :port, "Cyc port", as: Integer
  on :h=, :host, "Cyc host"
end

begin
  options.parse
rescue
  puts options
  exit
end

def term_to_output(cyc_term)
  [cyc_term.id,cyc_term.to_ruby.to_s]
end

def select_compatible(terms,parents,cyc)
  parents.map!{|parent| parent.gsub!('_', '-')}
  terms.select do |term|
    ((cyc.all_genls(term) || []).map(&:to_s) & parents).size > 0
  end
end

cyc = Cyc::Client.new(port: options[:port] || 3601, host: options[:host] || "localhost")
name_service = Mapping::CycNameService.new(cyc)

missing = CSV.open(options[:missing],"w")
ambiguous = CSV.open(options[:ambiguous],"w")
CSV.open(options[:mapping],"w") do |output|
  CSV.open(options[:input]) do |input|
    input.each do |name,label,*parents|
      begin
        name.chomp!
        #puts name
        umbel_name = name.dup
        name.gsub!("_","-")
        cyc_term = name_service.find_by_term_name(name)
        unless cyc_term.nil?
          output << [umbel_name,*term_to_output(cyc_term)]
          next
        end
        label.to_s.strip!
        begin
          cyc_term = name_service.find_by_label(label)
          unless cyc_term.nil?
            output << [umbel_name,*term_to_output(cyc_term)]
            next
          end
        rescue Mapping::AmbiguousResult => ex
          compatible_results = select_compatible(ex.results,parents,cyc)
          if compatible_results.size == 1
            puts compatible_results.first.inspect.hl(:blue)
            output << [umbel_name,*term_to_output(compatible_results.first)]
            next
          end
          puts compatible_results.inspect.hl(:red)
          ambiguous << [umbel_name,label,*parents]
          next
        end
        cyc_terms = name_service.find_by_name(label)
        if cyc_terms.size == 1
          output << [umbel_name,*term_to_output(cyc_terms.first)]
          next
        elsif cyc_terms.size > 1
          compatible_results = select_compatible(cyc_terms,parents,cyc)
          if compatible_results.size == 1
            puts compatible_results.first.inspect.hl(:blue)
            output << [umbel_name,*term_to_output(compatible_results.first)]
            next
          end
          puts compatible_results.inspect.hl(:red)
          ambiguous << [umbel_name,label,*parents]
          #ambiguous << [umbel_name,*cyc_terms.map{|t| term_to_output(t)}.flatten(1)]
          next
        end
        puts(("%-20s %s" % [umbel_name,label]).hl(:red))
        missing << [umbel_name,label,*parents]
      rescue Interrupt
        puts
        break
      rescue Exception => ex
        puts(("%-20s %s" % [umbel_name,label]).hl(:red))
        missing << [umbel_name,label,*parents]
        puts ex
        puts ex.backtrace[0..5]
      end
    end
  end
end
missing.close
ambiguous.close
