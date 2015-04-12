module Rlp
  module Wiki
    # The semantic kinds (genus proximum) determined from the first sentence.
    class Kind < Model
      # The name of the kind.
      field :name, :string, :index => :hash

      # The concepts that belong to this kind.
      has_many :concepts

      # The parents of the kind, i.e. kinds which are more general.
      has_many :parents, :class_name => "Rlp::Wiki::Kind"

      # The children of the kind, i.e. kinds which are more specific.
      has_many :children, :class_name => "Rlp::Wiki::Kind"

      # The Cyc terms that are mapped to this kind. The ideal situation
      # is when there is only one such term.
      has_many :terms

      # The Wikipedia categories that might correspond to this kind.
      has_many :categories

      validates_presence_of :name

      # Returns all children (direct and indirect) of the kind.
      def all_children
        (self.children.to_a + self.children.map{|c| c.all_children}.flatten).uniq
      end

      # Returns the ancestors of this kind.
      def ancestors
        ([self] + self.parents.map{|p| p.ancestors}).flatten.uniq
      end

      # The root parents of this kind, that is kinds without parents.
      def roots
        self.parents.empty? ? [self] : self.parents.map{|p| p.roots}.flatten.uniq
      end

      # Returns kinds that are mapped to terms or empty array.
      def mapped
        if self.terms.size > 0
          [self]
        else
          if parents.size > 0
            self.parents.to_a
          else
            []
          end
        end
      end

      # The Cyc terms that might be a good categorization
      # of this Wikipedia kind (direct or via parent kinds).
      def linked_terms
        return @linked_terms if defined?(@linked_terms)
        @linked_terms = []
        self.roots.each do |kind|
          if kind.terms.first
            @linked_terms += kind.terms.to_a
          elsif kind.categories.any?{|c| !c.linked_terms.empty?}
            @linked_terms += kind.categories.map{|c| c.linked_terms }.flatten
          end
        end
        @linked_terms.uniq!
        @linked_terms
      end
    end
  end
end
