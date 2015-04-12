require_relative 'node'

module Syntax
  module Stanford
    class Converter
      # Creates the converter for the description of the tree provided in
      # Stanford NLP notation.
      def initialize(description,options={})
        @node_factory = options.fetch(:node_factory,Node)
        @description = description.dup
        @node_index = 0
      end

      # Returns array representation of the sentence.
      # The tree is constructed as an array with embedded arrays.
      def array_tree
        return @array_tree if @array_tree
        @description.strip!
        #@description.gsub!(/[^\s()]+/, '"\0"')
        @description.gsub!(/[^\s()]+/) {|w| '"'+w.gsub('"', '\'')+'"'}
        @description.gsub!('(', '[')
        @description.gsub!(')', ']')
        @description.gsub!(/\s+/," ")
        @description.gsub!(' ', ', ')
        @description.gsub!('\\', '\\\\\\')
        begin
          @array_tree = eval(@description) # TODO safety level
        rescue Exception => ex
          puts "Error while parsing:\n#{@description}"
        end
        @array_tree
      end

      # Returns object representation of the sentence.
      # The tree is constructed as a graph of (Ruby) tree nodes.
      def object_tree
        head, *rest = array_tree
        object_subtree(head,rest)
      end

      private
      def object_subtree(head,rest,tree=nil)
        node = @node_factory.new(next_id, head)
        if tree
          tree << node
        else
          tree = node
        end

        if rest.size == 1 && String === rest.first
          node << @node_factory.new(next_id, rest.first)
        else
          rest.each do |head,*rest|
            object_subtree(head,rest,node)
          end
        end
        tree
      end

      def next_id
        @node_index += 1
      end
    end
  end
end
