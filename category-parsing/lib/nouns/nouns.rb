require 'csv'

class Nouns
  
  # Argument path locates directory with CSV files form Wiktionary
  # @param [String] path
  def initialize(path='../category-parsing/data/nouns')
    @plural_to_singulars = Hash.new
    @singular_to_plurals = Hash.new
    load(path)
  end
  
  # Indicate if noun is in singular form (or uncountable).
  def singular?(noun)
    @singular_to_plurals.has_key?(noun)
  end
  
  # Indicate if noun is in plural form.
  def plural?(noun)
    @plural_to_singulars.has_key?(noun)
  end
  
  # Returns list of possible singular forms of noun.
  def singularize(noun)
    @plural_to_singulars[noun]
  end
  
  # Fixes wrong identified noun numbers in Stanford Parser tree.
  # Returns number of changes
  def fix_penn_tree(tree)
    changes = 0
    first = true
    tree.each_leaf do |l|
      if l.parent.content =~ /^NNP?S=H$/ # plural TODO =H
        word = l.content
        if not self.plural?(word) and not (first and self.plural?(word.downcase)) and (self.singular?(word) or (first and self.singular?(word.downcase)))
          l.parent.content.sub!('S', '') 
          #p l.parent
          changes += 1
        end
      elsif l.parent.content =~ /^NNP?=H$/ # singular
        word = l.content
        if self.plural?(word) or (first and self.plural?(word.downcase))
          l.parent.content.sub!('=','S=')
          #p l.parent
          changes += 1
        end
      end
      first = false
    end
    return changes
  end
  
  private
  
  def load(path)
    nouns_names = ['noun','noun_uncountable','noun_usually_uncountable','noun_countable_and_uncountable','noun_non_attested','noun_unknown','noun_pluralia_tantum','noun_proper']
    files = Hash.new
    nouns_names.each do |noun|
      files[noun]=CSV.open(path+'/'+noun+'.csv')
    end
    
    ['noun','noun_usually_uncountable','noun_countable_and_uncountable'].each do |noun_name|
      files[noun_name].each do |singular,*plurals|
        add(singular,plurals)
      end
    end

    files['noun_uncountable'].each do |singular|
      add_uncountable(singular.first)
    end

    files['noun_pluralia_tantum'].each do |singular|
      add(singular.first,singular)
    end

    files.each do |_,file|
      file.close
    end
  end
  
  def add(singular,plurals)
    plurals.each do |plural|
      (@plural_to_singulars[plural] ||= []) << singular
      (@singular_to_plurals[singular] ||= []) << plural
    end
  end
  
  def add_uncountable(singular)
    (@singular_to_plurals[singular] ||= [])
  end
end