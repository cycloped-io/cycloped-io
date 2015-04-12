require 'set'

module Resolver
  class GraphWalker
    def initialize(&operation)
      @operation = operation
    end

    def apply(nodes,direction,accumulator)
      visited = Set.new
      queue = nodes.to_a.dup
      while(!queue.empty?) do
        node = queue.shift
        next if visited.include?(node)
        visited << node
        accumulator = @operation.call(accumulator,node)
        queue.concat(node.send(direction).to_a)
      end
      accumulator
    end
  end
end
