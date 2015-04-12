require 'set'

module Resolver
  class Divider
    def initialize(&disjointness_service)
      @service = disjointness_service
    end

    def partitions(graph)
      leafs = graph.leafs
      partitions = []
      # find partitions
      leafs.each do |node1|
        partition = Set.new([node1])
        partitions << partition
        leafs.each do |node2|
          next if node1 == node2
          partition << node2 unless partition.any?{|n| @service.call(n.value,node2.value) }
        end
      end
      partitions.uniq!
      # remove outliers
      occurrences = Hash.new(0)
      partitions.each{|p| p.each {|n| occurrences[n] += 1} }
      occurrences.each do |node,count|
        if count == occurrences.size && count > 2
          partitions.each{|p| p.delete(node) }
          partitions << [node]
        end
      end
      partitions
    end
  end
end
