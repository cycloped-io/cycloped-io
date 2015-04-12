module Umbel
  class ReferenceConcept
    attr_accessor :parents, :name, :children, :label, :cyc_id

    def initialize(name, label, parents)
      @name = name
      @label = label
      @parents = parents
      @children = []
    end

    def to_s
      '[%s - %s: %s]' % [self.name, self.label, self.parents.map { |parent| parent.name }.join(',')]
    end

    # Returns set of all ancestors.
    def all_parents
      all_parents = Set.new
      stack = parents.dup
      while !stack.empty?
        parent = stack.pop
        next if all_parents.include? parent
        all_parents.add parent
        parent.parents.each do |new_parent|
          stack.unshift new_parent
        end
      end
      all_parents
    end

    # Returns list of Super Types
    def super_types
      all_parents.select { |rc| rc.is_a?(SuperType) }
    end
  end
end
