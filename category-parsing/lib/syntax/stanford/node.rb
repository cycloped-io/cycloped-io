require 'rubytree'

module Syntax
  module Stanford
    # This class represents single node in a parse tree of an English sentence
    # according to Stanford NLP parser.
    class Node < ::Tree::TreeNode
      attr_accessor :dependencies_to, :dependencies_from

      # Creates new syntax node.
      def initialize(id,contents)
        super(node_description(id,contents),contents)
        @id = id
        @dependencies_to = Hash.new{|h,v| h[v]=[]}
        @dependencies_from = Hash.new{|h,v| h[v]=[]}
      end

      def add_dependency_to(dependency_name, node)
        @dependencies_to[dependency_name] << node
      end

      def add_dependency_from(dependency_name, node)
        @dependencies_from[dependency_name] << node
      end

      # Prints node representation according to the Stanford parser format.
      def to_s(indent=false,depth=0)
        offset = indent ? ("\n " + '  ' * depth) : ''
        if self.children.empty?
          if depth == 0
            offset + "(#{self.content})"
          else
            offset + self.content.to_s
          end
        else
          "#{offset}(#{self.content} #{self.children.map{|c| c.to_s(indent,depth+1)}.join(' ')})"
        end
      end

      # Prints tree structure representation without content
      def tree_without_content(indent=false,depth=0)
        offset = indent ? ("\n " + '  ' * depth) : ''
        if not self.children.empty?
          "#{offset}(#{self.content} #{self.children.map{|c| c.tree_without_content(indent,depth+1)}.join(' ')})"
        end
      end

      # Prints tree structure representation without content and word level nodes
      def tree_without_content_and_word_level(indent=false,depth=0) # TODO spaces remove
        offset = indent ? ("\n " + '  ' * depth) : ''
        if not self.children.empty? and self.phrase?
          #a=self.children.map{|c| c.tree_without_content_and_word_level(indent,depth+1)}
          "#{offset}(#{self.content} #{self.children.map{|c| c.tree_without_content_and_word_level(indent,depth+1)}.select{|c| not c.nil?}.join(' ')})"
        end
      end

      # Print literal conetns of the expression (i.e. words without parsing
      # data).
      def to_literal
        if self.children.empty?
          self.content.to_s
        else
          self.children.map{|c| c.to_literal }.join(" ")
        end
      end

      # Checks if node is head
      def head?
        content =~ /=H$/
      end

      # Checks if node is noun
      def nominal?
        content =~ /^N/
      end

      # Checks if node is plural noun
      def plural_noun?
        !!(content =~ /^NNP?S/)
      end

      # Checks if node is noun phrase
      def noun_phrase?
        content =~ /^NP/
      end

      # Checks if node is prepositional phrase
      def prepositional_phrase?
        content =~ /^PP/
      end

      # Checks if node is parenthetical
      def parenthetical?
        content =~ /^PRN/
      end

      # Checks if node is phrase or clause
      def phrase?
        content =~ /^(ADJP|ADVP|CONJP|INTJ|LST|NAC|NP|NX|PP|PRN|PRT|QP|RRC|UCP|VP|WHADJP|WHAVP|WHNP|WHPP|X|S|SBAR|SBARQ|SINV|SQ|ROOT)/
      end

      # Returns first ancestor of leaf which is noun phrase
      def find_parent_np
        node = self
        if ['NP', 'NP=H'].include?(node.content)
          return node
        end
        while not node.parent.nil? and not ['NP', 'NP=H'].include?(node.parent.content)
          node = node.parent
        end
        if node.parent.nil?
          node
        else
          node.parent
        end
      end


      # Finds head leaf in subtree
      def find_head_noun
        node = self
        while node.has_children?
          #p node
          if node.children.size == 1
            node=node.first_child
            next
          end
          new_node = nil
          node.children.each do |c|
            if c.head?
              new_node = c
              break
            end
          end
          if new_node.nil?
            new_node=node.last_child
          end
          node=new_node
          # what if none
        end
        return node
      end

      private
      def node_description(id,contents)
        "#{id}-#{contents}"
      end

    end
  end
end
