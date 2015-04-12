#!/usr/bin/env ruby

require 'bundler/setup'
require 'csv'
require 'slop'
require 'progress'
$:.unshift '../category-parsing/lib'
require 'syntax/penn_tree'
require 'syntax/parsed_sentence'
require 'syntax/dependencies'
require 'syntax/stanford/converter'
require 'nouns/nouns'
$:.unshift '../category-mapping/lib'
require 'umbel/serializer'


options = Slop.new do
  banner "Usage: #{$PROGRAM_NAME} -c parsed_articles.csv -o parsed_articles_with_types.csv -e errors.csv\n"+
             'Extracts definition words from first sentence.'

  on :c=, 'parsed_articles', 'Parsed articles', required: true
  on :o=, 'output', 'Parsed articles with types', required: true
  on :e=, 'errors', 'Articles without found types', required: true
end
begin
  options.parse
rescue Slop::MissingOptionError
  puts options
  exit
end


class Definition
  attr_accessor :introductory_word, :node

  def initialize(introductory_word, definition)
    @introductory_word=introductory_word
    @node=definition
  end

  def ==(other)
    @introductory_word == other.introductory_word && @node==other.node
  end

  def eql?(other)
    self == other
  end

  def hash
    [@introductory_word, @node].hash
  end

  def to_s
    @introductory_word.to_s+@node.to_s
  end

  def to_csv
    [@introductory_word, @node.find_parent_np.to_s]
  end
end

def get_multi(definition)
  multi = [definition]

  conjuctions_to = ['conj_and', 'conj_or'].select { |relation| definition.node.dependencies_to.include?(relation) }.map { |relation| definition.node.dependencies_to[relation] }.flatten
  multi.concat(conjuctions_to.map { |conjuction| Definition.new(definition.introductory_word, conjuction) })
  conjuctions_from = ['conj_and', 'conj_or'].select { |relation| definition.node.dependencies_from.include?(relation) }.map { |relation| definition.node.dependencies_from[relation] }.flatten
  multi.concat(conjuctions_from.map { |conjuction| Definition.new(definition.introductory_word, conjuction) })

  return multi.uniq
end

WORD_PREPOSITION = {'name' => ['prep_of', 'prep_for'],
                    'type' => ['prep_of'],
                    'group' => ['prep_of'],
                    'form' => ['prep_of'],
                    'genus' => ['prep_of', 'prep_in'],
                    'family' => ['prep_of'],
                    'term' => ['prep_for'],
                    'set' => ['prep_of'],
                    'branch' => ['prep_of'],
                    'species' => ['prep_of', 'prepc_of'],
                    'collection' => ['prep_of'],
                    'class' => ['prep_of'],
                    'order' => ['prep_of'],
                    'breed' => ['prep_of'],
                    'genre' => ['prep_of'],
                    'piece' => ['prep_of'],
                    'kind' => ['prep_of'],
                    'version' => ['prep_of'],
                    'variety' => ['prep_of'],
                    'word' => ['prep_for'],
                    'model' => ['prep_of'],
                    'line' => ['prep_of'],
                    'brand' => ['prep_of'],
                    'subgenre' => ['prep_of'],
                    'sub-genre' => ['prep_of'],
                    'category' => ['prep_of'],
                    'pair' => ['prep_of'],
                    'layer' => ['prep_of'],
                    'chain' => ['prep_of'],
                    'subset' => ['prep_of'],
                    'groups' => ['prep_of'],
                    'edition' => ['prep_of'],
                    'subgroup' => ['prep_of'],
                    'terms' => ['prep_for'],
                    'article' => ['prep_about'],
                    'example' => ['prep_of'],
                    'suborder' => ['prep_of'],
                    'spelling' => ['prep_of'],
                    'types' => ['prep_of'],
                    'sets' => ['prep_of'],
                    'clade' => ['prep_of'],
                    'list' => ['prep_of'],
                    'lists' => ['prep_of']}

def check_prep(definitions)
  # if this is "introductory" word with defined preposition then follow
  change=true
  while change
    change=false
    results = []
    definitions.each do |definition|
      word = definition.node.content
      if WORD_PREPOSITION.include?(word) && WORD_PREPOSITION[word].any? { |relation| definition.node.dependencies_to.include?(relation) }
        results.concat(WORD_PREPOSITION[word].map { |relation| definition.node.dependencies_to[relation] }.flatten.map { |x| Definition.new(word, x) })
        change = true
      else
        results.push definition
      end
    end
    definitions = results
  end

  return results.uniq
end

def multi(definitions)
  multi_definitions = definitions.map { |definition| get_multi(definition) }.flatten.select { |definition| definition.node.parent.nominal? }
  prep_multi_definitions = check_prep(multi_definitions)
end


def process(node)
  return multi([Definition.new(nil, node)])
end


NONNOUN_PREPOSITION = {'refers' => ['prep_to'],
                       'referred' => ['prep_to', 'prep_as_to'],
                       'refer' => ['prep_to'],
                       'describe' => ['dobj'],
                       'describes' => ['dobj'],
                       'described' => ['prep_as'],
                       'denotes' => ['dobj'],
                       'name' => ['prep_for', 'prep_of'],
                       'set' => ['prep_of'],
                       'defined' => ['prep_as'],
                       'used' => ['prep_as']
}

nouns = Umbel::Serializer.auto(Nouns)

file_parsed_categories = CSV.open(options[:parsed_articles], 'r:utf-8', :row_sep => "\r\n")
file_output = CSV.open(options[:output], 'w:utf-8')
file_errors = CSV.open(options[:errors], 'w:utf-8')

stats = Hash.new(0)
stats2 = Hash.new { |h, k| h[k]=[] }

file_parsed_categories.with_progress do |row|

  article_name, sentence, full_parse, dependency=row


  if sentence.nil? || full_parse.nil? || dependency.nil?
    file_errors << row
    next
  end

  tree = Syntax::PennTree.new(full_parse)
  nouns.fix_penn_tree(tree.tree)
  dependencies = Syntax::Dependencies.new(dependency.split("\n"))
  parsed_sentence = Syntax::ParsedSentence.new(tree, dependencies)


  result = nil
  deps_cop = parsed_sentence.dependencies('cop').map { |n1, n2| n1 }
  deps_cop_n = deps_cop.select { |n1| n1.parent.nominal? }

  deps_nsubj = parsed_sentence.dependencies('nsubj').map { |n1, n2| n1 }
  deps_nsubj_n = deps_nsubj.select { |n1| n1.parent.nominal? }

  deps_root = parsed_sentence.dependencies('root').map { |n1, n2| n2 }
  deps_root_n = deps_root.select { |n1| n1.parent.nominal? }

  deps_all_n = [deps_cop_n, deps_nsubj_n, deps_root_n]


  if deps_all_n.all? { |deps| !deps.empty? }
    types = deps_all_n.map { |deps| deps.first }
    #p types
    if types.uniq.size==1
      result = types.first
      stats['confident'] += 1
      stats2[result.to_s] << sentence if result.dependencies_to.keys.any? { |key| key.start_with?('prep') }

      file_output << row + process(result).map { |definition| definition.to_csv }.flatten
    elsif types.uniq.size==2 && types[0]!=types[1] && deps_cop_n.include?(types[0])
      result = types[1]
      stats['confident2'] += 1
      file_output << row + process(result).map { |definition| definition.to_csv }.flatten
    elsif types.uniq.size==2 && types[0]==types[1]
      result = types[1]
      stats['confident3'] += 1
      file_output << row + process(result).map { |definition| definition.to_csv }.flatten
    else

      stats['other1'] += 1
      file_errors << row

    end
  else
    stats['other2'] += 1


    if article_name =~ /geography|politics/i
      stats['blacklisted']+=1
    end
    if sentence.include?('(')
      stats['bracket']+=1
    end
    if sentence.include?('"')
      stats['quote']+=1
    end
    if sentence.include?('/')
      stats['slash']+=1
    end
    if sentence.include?('refer')
      stats['refer']+=1
    end

    deps_all = [deps_cop, deps_nsubj, deps_root]
    if deps_all.all? { |deps| !deps.empty? }
      stats['all'] +=1
      types = deps_all.map { |deps| deps.first }
      if types.uniq.size==1
        if ['one', 'any'].include?(types.first.content) && types.first.dependencies_to.include?('prep_of')
          stats['one|any'] +=1

          result = types.first.dependencies_to['prep_of'].first
          file_output << row + process(result).map { |definition| definition.to_csv }.flatten
        else
          stats['same'] +=1
          file_errors << row
        end
      else
        stats['other3'] +=1
        file_errors << row
      end
    else
      stats['other4'] +=1
      root = deps_root.first
      if !root.nil? && NONNOUN_PREPOSITION.include?(root.content)
        relations = NONNOUN_PREPOSITION[root.content]
        common = (relations&root.dependencies_to.keys)
        if !common.empty?
          types = common.map { |relation| root.dependencies_to[relation] }.flatten
          result = types.first
          file_output << row + process(result).map { |definition| definition.to_csv }.flatten
          stats['conf refers']+=1
        else
          stats['other5'] +=1
          file_errors << row
        end
      else
        stats['other6'] +=1
        file_errors << row
      end
    end
  end
end


file_parsed_categories.close
file_output.close
file_errors.close


p stats

stats2.sort_by { |k, v| v.size }.reverse.each do |k, v|
  puts k+' - '+v.size.to_s
  v.shuffle[0..3].each do |s|
    puts ' - '+s
  end
end

=begin

Parsed file: definitions2_00 [199948 sentences].
Parsed 4360652 words in 199948 sentences (26,49 wds/sec; 1,21 sents/sec).

real    2743m20.347s
user    2730m49.066s
sys     3m41.434s

Parsed file: definitions2_01 [199917 sentences].
Parsed 4111577 words in 199917 sentences (28,06 wds/sec; 1,36 sents/sec).
  1 sentences were not parsed:
    1 were skipped as length 0 or greater than 100

real    2442m17.017s
user    2429m1.295s
sys     3m19.871s

Parsed file: definitions2_02 [199985 sentences].
Parsed 4029432 words in 199985 sentences (28,80 wds/sec; 1,43 sents/sec).

real    2332m1.169s
user    2320m43.173s
sys     3m11.900s

Parsed file: definitions2_03 [199978 sentences].
Parsed 3887100 words in 199978 sentences (29,99 wds/sec; 1,54 sents/sec).

real    2160m38.773s
user    2146m29.421s
sys     2m52.832s

Parsed file: definitions2_04 [199975 sentences].
Parsed 3845433 words in 199975 sentences (29,56 wds/sec; 1,54 sents/sec).

real    2168m4.825s
user    2157m37.724s
sys     2m56.382s

Parsed file: definitions2_05 [199993 sentences].
Parsed 3777307 words in 199993 sentences (29,40 wds/sec; 1,56 sents/sec).

real    2141m28.778s
user    2126m57.142s
sys     2m52.390s
=end

# {"confident"=>3264199, "other2"=>427323, "all"=>184906, "one|any"=>47453, "other4"=>242417, "other6"=>210487, "confident2"=>1698, "other3"=>105488, "same"=>31965, "blacklisted"=>588, "refer"=>31471, "conf refers"=>21181, "quote"=>32034, "other5"=>10749, "slash"=>7115, "confident3"=>34774, "other1"=>67}