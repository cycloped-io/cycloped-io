module Syntax
  module Stanford
    # This class is intended to simplify the parse tree of an expression.
    # Its mode of operation is straightforward - at first it removes the part
    # that is on the left of the head, then removes each subexpression that is
    # on the right.
    class Simplifier
      # Initialize the simplifier with a parsed tree of the expression.
      def initialize(node)
        @node = node
      end

      # This method returns an iterator that in each step yeilds a more
      # simplified version of the exprestion, staring with the whole expression
      # and ending with the sole head.
      def simplify
        if block_given?
          head = @node.find_head_noun
          head_index = @node.children.each.with_index{|e,i| break i if e.to_literal == head.to_literal }
          head_index = nil unless Numeric === head_index
          if head_index == @node.children.size - 1
            @node.children.size.times do |index|
              yield @node.children[index..-1].map{|c| c.to_literal }.join(" ")
            end
          else
            yield @node.to_literal
            if head_index
              children = @node.children[0..head_index]
              children.size.times do |index|
                yield children[index..-1].map{|c| c.to_literal }.join(" ")
              end
            end
          end
        else
          enum_for(:simplify)
        end
      end
    end
  end
end
