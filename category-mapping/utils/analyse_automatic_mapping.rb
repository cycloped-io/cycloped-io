#!/usr/bin/env ruby

require 'set'
require 'slop'
require 'cycr'
require 'csv'
require 'colors'
$:.unshift "lib"
require 'mapping/cyc_term'
require 'mapping/service/cyc_name_service'

options = Slop.new do
  banner "#{$PROGRAM_NAME}"

end

begin
  options.parse
rescue
  puts options
  exit
end

def term_to_output(cyc_term)
  [cyc_term.id, cyc_term.to_ruby.to_s]
end

def select_compatible(terms, parents, cyc)
  terms.select do |term|
    ((cyc.all_genls(term) || []).map(&:to_s) & parents).size > 0
  end
end

cyc = Cyc::Client.new(port: options[:port] || 3601, host: options[:host] || "localhost")
name_service = Mapping::Service::CycNameService.new(cyc)


added = File.open('data/added_to_umbel.txt')
new = Set.new
added.each do |umbel_name|
  new.add umbel_name.strip
end
added.close

umbel_to_cyc = Hash.new
cycterm_to_cycid = Hash.new
cyc_umbel = CSV.open('data/cyc_wiki_umbel.csv')
cyc_umbel.each do |term, umbel, dbpedia, wiki, cycterm|
  if not umbel.nil?
    umbel_to_cyc[umbel] = term
  end
  unless cycterm.nil?
    cycterm_to_cycid[cycterm] = term
  end
end
cyc_umbel.close

umbel_to_cyc_2008 = Hash.new
cycterm_to_cycid_2008 = Hash.new
cyc_umbel = CSV.open('data/cyc_wiki_umbel-2008.csv')
cyc_umbel.each do |term, umbel, dbpedia, wiki, cycterm|
  if not umbel.nil?
    umbel_to_cyc_2008[umbel] = term
  end
  unless cycterm.nil?
    cycterm_to_cycid_2008[cycterm] = term
  end
end
cyc_umbel.close


deleted = Hash.new
different = Hash.new
different2008 = Hash.new

map = Hash.new

automatic_mapping = Hash.new

mapping = CSV.open('mapping.csv')
mapping.each do |umbel_name, cyc_id, cyc_term|
  automatic_mapping[umbel_name] = [cyc_id, cyc_term]

  if umbel_to_cyc.has_key? umbel_name and umbel_to_cyc[umbel_name]!=cyc_id
    cyc_term2 = name_service.find_by_id(umbel_to_cyc[umbel_name])
    puts 'Different Cyc mapping: '+umbel_name+' '+name_service.find_by_id(cyc_id).to_ruby.to_s+' '+cyc_term2.to_ruby.to_s+' '+umbel_to_cyc[umbel_name]
    map[umbel_name] = [umbel_to_cyc[umbel_name], cyc_term2.to_ruby.to_s]
    different[umbel_name] = [cyc_term2.to_ruby.to_s, cyc_term]
  elsif umbel_to_cyc_2008.has_key? umbel_name and umbel_to_cyc_2008[umbel_name]!=cyc_id
    cyc_term2 = name_service.find_by_id(umbel_to_cyc_2008[umbel_name])
    if cyc_term2.nil?
      puts 'Deleted 2008 Cyc term: '+umbel_name+' '+name_service.find_by_id(cyc_id).to_ruby.to_s+' '+umbel_to_cyc_2008[umbel_name]
      map[umbel_name] = [cyc_id, cyc_term]
      deleted[umbel_name] = umbel_to_cyc_2008[umbel_name]
    else
      puts 'Different Cyc 2008 mapping: '+umbel_name+' '+name_service.find_by_id(cyc_id).to_ruby.to_s+' '+cyc_term2.to_ruby.to_s
      map[umbel_name] = [umbel_to_cyc_2008[umbel_name], cyc_term2.to_ruby.to_s]
      different2008[umbel_name] = [cyc_term2.to_ruby.to_s, cyc_term]
    end
  elsif new.include? umbel_name
    puts 'ADDED but found in Cyc: '+umbel_name+' '+cyc_term
    map[umbel_name] = [cyc_id, cyc_term]
  else
    map[umbel_name] = [cyc_id, cyc_term]
  end
end

puts
miss = Hash.new

missing = CSV.open('missing.txt')
missing.each do |umbel_name, label, *parents|

  if umbel_to_cyc.has_key? umbel_name
    cyc_term2 = name_service.find_by_id(umbel_to_cyc[umbel_name])
    puts 'Cyc mapping: '+umbel_name+' '+cyc_term2.to_ruby.to_s
    map[umbel_name] = [umbel_to_cyc[umbel_name], cyc_term2.to_ruby.to_s]
  elsif umbel_to_cyc_2008.has_key? umbel_name
    cyc_term2 = name_service.find_by_id(umbel_to_cyc_2008[umbel_name])
    if cyc_term2.nil?
      puts 'Deleted 2008 Cyc term: '+umbel_name+' '+umbel_to_cyc_2008[umbel_name]
      miss[umbel_name] = [label, *parents]
      deleted[umbel_name] = umbel_to_cyc_2008[umbel_name]
    else
      puts 'Cyc 2008 mapping: '+umbel_name+' '+cyc_term2.to_ruby.to_s
      map[umbel_name] = [umbel_to_cyc_2008[umbel_name], cyc_term2.to_ruby.to_s]
    end
  elsif new.include? umbel_name
    puts 'ADDED: '+umbel_name
    miss[umbel_name] = [label, *parents]
  else
    miss[umbel_name] = [label, *parents]
  end
end

puts
ambig = Hash.new

missing = CSV.open('ambiguous.csv')
missing.each do |umbel_name, label, *parents|

  if umbel_to_cyc.has_key? umbel_name
    cyc_term2 = name_service.find_by_id(umbel_to_cyc[umbel_name])
    puts 'Cyc mapping: '+umbel_name+' '+cyc_term2.to_ruby.to_s
    map[umbel_name] = [umbel_to_cyc[umbel_name], cyc_term2.to_ruby.to_s]
  elsif umbel_to_cyc_2008.has_key? umbel_name
    cyc_term2 = name_service.find_by_id(umbel_to_cyc_2008[umbel_name])
    if cyc_term2.nil?
      puts 'Deleted 2008 Cyc term: '+umbel_name+' '+umbel_to_cyc_2008[umbel_name]
      ambig[umbel_name] = [label, *parents]
      deleted[umbel_name] = umbel_to_cyc_2008[umbel_name]
    else
      puts 'Cyc 2008 mapping: '+umbel_name+' '+cyc_term2.to_ruby.to_s
      map[umbel_name] = [umbel_to_cyc_2008[umbel_name], cyc_term2.to_ruby.to_s]
    end
  elsif new.include? umbel_name
    puts 'ADDED: '+umbel_name
    ambig[umbel_name] = [label, *parents]
  else
    ambig[umbel_name] = [label, *parents]
  end
end

fixed = []
different.each do |umbel, v|
  cyc_mapping = umbel_to_cyc[umbel]
  # if this is mapped to different umbel concept
  map.each do |umbel2, cycs|
    cycid = cycs[0]

    if cycid == cyc_mapping and umbel!=umbel2
      map[umbel] = automatic_mapping[umbel]
      fixed.push umbel
    end
  end
end

fixed.each do |umbel|
  different.delete umbel
end




puts '## Cyc concepts (from 2008 too) with the same name as Umbel concept, but with different mapping'
puts
puts '| Umbel | Proposed mapping | Cyc same name concept id | Cyc name currently |'
puts '| --- | --- | --- | --- |'
map.each do |umbel, v|
  cycid=v[0]
  cycterm = v[1]
  name = umbel.gsub('_', '-')
  if cycterm_to_cycid_2008.has_key? name and cycterm_to_cycid_2008[name] != cycid
    term = name_service.find_by_id(cycterm_to_cycid_2008[name])
    invalid = term.nil?
    puts '| '+umbel + ' | ' + cycid+' ('+cycterm+ ') | ' + cycterm_to_cycid_2008[name]+' | '+((invalid)?' (deleted)':' '+term.to_ruby.to_s) +' |'
  elsif cycterm_to_cycid.has_key? name and cycterm_to_cycid[name] != cycid
    term = name_service.find_by_id(cycterm_to_cycid[name])
    puts '| '+umbel + ' | ' + cycid+' ('+cycterm+ ') | ' + cycterm_to_cycid[name]+' | '+term.to_ruby.to_s + ' |'
  end
end


puts
puts '## Among missing - Cyc concepts (from 2008 too) with the same name as Umbel concept'
puts
puts '| Umbel | Cyc same name concept | Cyc name currently |'
puts '| --- | --- | --- |'
fixed=[]
miss.each do |umbel, v|
  name = umbel.gsub('_', '-')

  if cycterm_to_cycid_2008.has_key? name
    term = name_service.find_by_id(cycterm_to_cycid_2008[name])
    invalid = term.nil?
    puts '| '+umbel + ' | ' + cycterm_to_cycid_2008[name] +' | '+((invalid)?' (deleted)':' '+term.to_ruby.to_s) +' |'
    if not invalid
      map[umbel] = [name, cycterm_to_cycid_2008[name]]
      fixed.push umbel
    end
  elsif cycterm_to_cycid.has_key? name
    term = name_service.find_by_id(cycterm_to_cycid[name])
    puts 'X| '+umbel + ' | ' + cycterm_to_cycid[name] +' | '+term.to_ruby.to_s+' |'
    map[umbel] = [name, cycterm_to_cycid[name]]
    fixed.push umbel
  end
end
fixed.each do |umbel|
  miss.delete umbel
end

puts
puts '## Among ambiguous - Cyc concepts (from 2008 too) with the same name as Umbel concept'
puts
puts '| Umbel | Cyc same name concept | Cyc name currently |'
puts '| --- | --- | --- |'
fixed=[]
ambig.each do |umbel, v|
  name = umbel.gsub('_', '-')

  if cycterm_to_cycid_2008.has_key? name
    term = name_service.find_by_id(cycterm_to_cycid_2008[name])
    invalid = term.nil?
    puts '| '+umbel + ' | ' + cycterm_to_cycid_2008[name] +' | '+((invalid)?' (deleted)':''+term.to_ruby.to_s) +' |'
    if not invalid
      map[umbel] = [name, cycterm_to_cycid_2008[name]]
      fixed.push umbel
    end
  elsif cycterm_to_cycid.has_key? name
    term = name_service.find_by_id(cycterm_to_cycid[name])
    puts 'X| '+umbel + ' | ' + cycterm_to_cycid[name] +' | '+term.to_ruby.to_s+' |'
    map[umbel] = [name, cycterm_to_cycid[name]]
    fixed.push umbel
  end
end
fixed.each do |umbel|
  ambig.delete umbel
end

puts





puts '## Mappings to the same Cyc id'
puts
puts '| Umbel 1 | Umbel 2 | Cyc name | Cyc id |'
puts '| --- | --- | --- | --- |'
used = Hash.new
map.each do |umbel, v|
  cycid=v[0]
  cycterm = v[1]
  if used.has_key? cycid
    puts '| '+umbel + ' | ' + used[cycid] + ' | ' + cycterm+' | '+cycid+' |'
  else
    used[cycid]=umbel
  end

end



p map.size
p miss.size
p ambig.size
puts 'Cyc to Umbel mappings: '+umbel_to_cyc.size.to_s
puts 'Cyc to Umbel 2008 mappings: '+umbel_to_cyc_2008.size.to_s


puts
puts '## Deleted Cyc ids after 2008: '+deleted.size.to_s
puts
puts '| Umbel | Deleted Cyc id |'
puts '| --- | --- |'
deleted.sort_by { |k, v| k }.each do |k, v|
  puts '| '+k+' | '+v+' |'
end

puts
puts 'Different automatic mapping to Cyc mapping: '+different.size.to_s
puts
puts '| Umbel | Cyc mapping | Automatic mapping |'
puts '| --- | --- | --- |'
different.sort_by { |k, v| k }.each do |k, v|
  puts '| '+k+' | '+v[0].to_s+' | '+v[1].to_s+' |'
end
puts 'Different to Cyc mapping 2008: '+different2008.size.to_s


f=CSV.open('mapping2.csv', 'w')
map.each do |k, v|
  f << [k, *v]
end
f.close

f=CSV.open('ambiguous2.csv', 'w')
ambig.each do |k, v|
  f << [k, *v]
end
f.close

f=CSV.open('missing2.csv', 'w')
miss.each do |k, v|
  f << [k, *v]
end
f.close


=begin

opencyc = File.read('opencyc-2008-06-10-readable.owl')


missing = CSV.open('missing.txt')
missing.each do |umbel_name,label,*parents|
  next if new.include? umbel_name
  name = umbel_name.dup
  name.gsub!("_","-")

  #znajdz w starym
  index = opencyc.index('="'+name+'"')
  if index
    m = /<owl:sameAs rdf:resource="http:\/\/sw.opencyc.org\/concept\/(.*?)"\/>/.match(opencyc, index)
    cyc_id = m[1]
    p [umbel_name, cyc_id]
  else
    #m = Regexp.new('.*'+name+'.*').match(opencyc)
    m=opencyc.scan( Regexp.new('.*'+name+'.*'))
    puts umbel_name
    puts m
    puts
  end



end
=end

