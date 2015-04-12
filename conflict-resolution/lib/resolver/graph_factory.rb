require 'set'

module Resolver
  class GraphFactory
    class Node
      attr_accessor :parents, :children, :value
      def initialize(value)
        @value = value
        @children = Set.new
        @parents = Set.new
      end

      def add_parent(parent)
        @parents << parent
      end

      def add_child(child)
        @children << child
      end

      def inspect
        "#{self.value} P:<#{@parents.map(&:value).join(", ")}> C:<#{children.map(&:value).join(", ")}>"
      end

      def to_s
        @value
      end

      def root?
        self.parents.empty?
      end

      def leaf?
        self.children.empty?
      end
    end

    class Graph
      attr_reader :roots

      def initialize(roots)
        @roots = roots.freeze
      end

      def leafs
        visited = Set.new
        queue = @roots.dup
        leafs = []
        while(!queue.empty?) do
          node = queue.shift
          next if visited.include?(node)
          visited << node
          leafs << node if node.leaf?
          queue.concat(node.children.to_a)
        end
        leafs
      end
    end

    def initialize(&edge_service)
      @service = edge_service
      @node_factory = Node
      @graph_factory = Graph
    end

    def create(entities)
      nodes = entities.map{|e| @node_factory.new(e) }
      roots = []
      nodes.each do |node1|
        nodes.each do |node2|
          next if node1 == node2
          edge_order = @service.call(node1.value,node2.value)
          if edge_order < 0
            node1.add_parent(node2)
            node2.add_child(node1)
          elsif edge_order > 0
            node2.add_parent(node1)
            node1.add_child(node2)
          end
        end
        roots << node1 if node1.root?
      end
      removal_map = Hash.new{|h,e| h[e] = Set.new }
      nodes.each do |node|
        node.parents.each do |parent|
          removal_map[node].merge(parent.parents)
        end
      end
      removal_map.each do |node,removed_parents|
        node.parents.subtract(removed_parents)
        removed_parents.each{|p| p.children.delete(node) }
      end
      @graph_factory.new(roots)
    end
  end
end
