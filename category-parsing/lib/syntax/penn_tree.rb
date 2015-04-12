

# NP - Noun Phrase.
# NN - Noun, singular or mass
# NNS - Noun, plural
# NNP - Proper noun, singular
# NNPS - Proper noun, plural
module Syntax
  class PennTree
    attr_accessor :tree

    def initialize(tree,options={})
      converter = options.fetch(:converter,Stanford::Converter)
      @tree = converter.new(tree).object_tree
    end
    
    def to_s
      @tree.to_s
    end
  
    # Finds head noun by taking first noun marked as head using BFS
    def find_head_noun_bfs
      @tree.breadth_each do |l|
        #if ['NP=H', 'NNS=H', 'NNPS=H', 'NNP=H', 'NN=H'].include?(l.content)
        if l.nominal? and l.head?
          return l.find_head_noun
        end
      end
      return nil
    end

    # Finds head noun by taking first noun marked as head using DFS
    def find_head_noun_dfs
      @tree.each do |l|
        #if ['NP=H', 'NNS=H', 'NNPS=H', 'NNP=H', 'NN=H'].include?(l.content)
        if l.nominal? and l.head?
          return l.find_head_noun
        end
      end
      return nil
    end

    # Finds head noun by taking first plural noun using DFS
    def find_plural_noun_dfs
      @tree.each_leaf do |l|
        #if ['NNS', 'NNPS', 'NNS=H', 'NNPS=H'].include?(l.parent.content)
        if l.parent.plural_noun?
          l.parent.parent.children.reverse_each do |c|
            if c.plural_noun? and c.children.size==1
              return c.first_child.find_head_noun
            end
          end
        end

      end
      return nil
    end

    # Finds head noun by taking first plural noun using BFS
    def find_plural_noun_bfs
      @tree.breadth_each do |l|
        #if ['NNS', 'NNPS', 'NNS=H', 'NNPS=H'].include?(l.content) # TODO VBZ=H ?
        if l.plural_noun?
          l.parent.children.reverse_each do |c|
            #if ['NNS', 'NNPS', 'NNS=H', 'NNPS=H'].include?(c.content)
            if c.plural_noun?
              return c.find_head_noun
            end
          end
        end

      end
      return nil
    end
    
    # 
    def find_last_plural_noun
      nodes = []
      @tree.each_leaf do |l|
        nodes.push l
      end
      nodes.reverse.each do |l|
        #if ['NNS', 'NNPS', 'NNS=H', 'NNPS=H'].include?(l.parent.content)
        if l.parent.plural_noun?
          l.parent.parent.children.reverse_each do |c|
            if c.plural_noun? and c.children.size==1
              return c.first_child.find_head_noun
            end
          end
        end

      end
      return nil
    end
    
    # 
    def find_last_nominal
      nodes = []
      @tree.each do |l|
        nodes.push l
      end
      
      nodes.reverse.each do |l|
        #if ['NP=H', 'NNS=H', 'NNPS=H', 'NNP=H', 'NN=H'].include?(l.content)
        if l.nominal? and l.head?
          
          return l.find_head_noun
        end
      end
      return nil
    end
    
    # TODO remove associated verb
    
    # Removes all prepositional phrases from tree
    def remove_prepositional_phrases! # TODO breaks dependencies
      @tree.breadth_each do |l|
        if l.prepositional_phrase?
          l.parent.remove!(l)
        end
      end
    end
    
    # Removes all parenthetical from tree
    def remove_parenthetical! # TODO breaks dependencies
      @tree.breadth_each do |l|
        if l.parenthetical?
          #p 'removed'
          l.parent.remove!(l)
        end
      end
    end
    
    # Removes all prepositional phrases from tree
    def remove_prepositional_phrases # TODO breaks dependencies
      tree=@tree.dup
      tree.breadth_each do |l|
        if l.prepositional_phrase?
          l.parent.remove!(l)
        end
      end
      return tree
    end

    # Returns potential heads fromm parsed head
    def heads
      arguments = []
      argument = []
      @tree.children.each do |node|
        if node.content == 'CC'
          arguments.push argument
          argument = []
        else
          argument << node
        end
      end
      arguments.push argument

      heads = []
      arguments.each do |argument|
        np = Stanford::Node.new(-1,'NP')
        argument.each do |node|
          np << node
        end
        heads << np
      end

      heads.select!{|np| np.find_head_noun.parent.nominal?}

      return heads

    end
  end
end