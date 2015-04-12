require 'graphviz'

module Resolver
  class Renderer
    def initialize(name,roots)
      @graph = GraphViz.new(name,rankdir: "LR")
      map = {}
      visited = Set.new
      queue = roots.dup
      relations = []
      while(!queue.empty?) do
        node = queue.shift
        next if visited.include?(node)
        visited << node
        @graph.add_nodes(node.to_s)
        node.children.each do |child|
          relations << [node,child]
        end
        queue.concat(node.children.to_a)
      end
      relations.each do |parent,child|
        @graph.add_edges(child.to_s,parent.to_s,dir: "back")
      end
    end

    def render(path,format="png")
      @graph.output(format => path)
    end
  end
end
