require 'set'
require 'syntax/stanford/converter'

module Rlp
  module Wiki
    # The categories are kept in +page.csv+ file and their type
    # is set to (2) (the type is the (3) field in the file.
    class Category < Page
      # The number of all children (transitive) of this category.
      field :all_children_count, :ulong

      # The number of all concepts that directly or transitively
      # belong to this category.
      field :all_concepts_count, :ulong

      # Indicates the status (as symbol) of the category.
      # Might be:
      # * :administartive (Wikipedia internal category, e.g. Hidden categories)
      # * :topic (topic category, e.g. Warsaw)
      # * :semantic (semantic categorie, e.g. Cities)
      field :status, :object

      # The parsed name of the category.
      field :parsed_name, :string

      # The phrase of the category name containing its head.
      field :parsed_head, :string

      # Boolean value indicating if the category name head is in plural.
      field :plural_head, :object

      # Some of the categories contain 'and' word which might indicate, that the
      # category covers two concepts. In such cases we provide all of the heads
      # in this filed as an array of strings consisting each parsed head
      # provided by the parser. It should be noted, that if one of the words has
      # a modifier it is not provided for the second head, even if it applies to
      # it. These heads are only in plural.
      field :parsed_heads, :object

      # The Cyc term that corresponds to this category. This should be
      # a final mapping - i.e. the confidence of the mapping should be
      # the highest and the mapping should not change in future.
      has_one :term

      # The concepts that belong to this category.
      # Their +wiki_ids+ are the (2) field in the +cagtegorylink.csv+ file.
      has_many :concepts

      # The children categories.
      # Their +wiki_ids+ are the (2) field in the +categorylink.csv+ file.
      has_many :children, :class_name => "Rlp::Wiki::Category"

      # The parent categories.
      # Their +wiki_ids+ are the (1) field in the +categorylink.csv+ file.
      has_many :parents, :class_name => "Rlp::Wiki::Category"

      # The kinds that might represent this category.
      has_many :kinds

      # The semantic parent of the category should be the categories
      # which have the same semantic kind (e.g. Polish universities -> Universities).
      has_many :semantic_parents, :class_name => "Rlp::Wiki::Category"

      # The semantic children is the opposite relation to semantic parent.
      has_many :semantic_children, :class_name => "Rlp::Wiki::Category"

      # The concepts which are equivalent to the category.
      # In most cases there is only one such concept, but if there is e.g. a list of
      # articles, the list is also linked.
      has_many :eponymous_concepts, :class_name => "Rlp::Wiki::Concept"


      # Indicates if the category is administrative, i.e. its purpose in
      # Wikipedia is not connected with regular navigation between articles but
      # rather
      def administrative?
        self.status == :administrative
      end

      # Mark the category as administrative and store in the DB.
      def administrative!
        return if administrative?
        self.status = :administrative
        self.store
      end

      # Indicates if the category is a stub, i.e. it bears semantic information,
      # but not expressed in plural head noun, but rather some modifier of the
      # "stub" word, e.g. "Law stubs"
      def stub?
        self.status == :stub
      end

      # Mark the category as stub and store in the DB.
      def stub!
        return if stub?
        self.status = :stub
        self.store
      end

      # Regular category is not administrative, neither stub category.
      def regular?
        !administrative? && !stub?
      end

      # Marks this category as containing a number in name. This applies only to
      # regular categories.
      def contains_number!
        return unless self.regular?
        self.status = :contains_number
        self.store
      end

      # Returns true if the category contains number.
      def contains_number?
        self.status == :contains_number
      end

      # Indicate if the category has plural head.
      def plural?
        self.plural_head
      end

      def multiple_heads?
        !!self.parsed_heads
      end

      # Returns the head NP as tree.
      def head_tree
        @head_tree ||= wrap_head_into_object(self.parsed_head)
      end

      # Returns heads NPs as tree objects (in case there are mulitple heads.
      def head_trees
        if self.multiple_heads?
          @head_trees ||= parsed_heads.map{|h| wrap_head_into_object(h) }
        else
          @head_trees ||= [self.head_tree]
        end
      end

      # Returns the noun that is the head of the name of the category.
      def head
        head_node = self.head_tree.find_head_noun
        head_node && head_node.content
      end

      # Returns the nouns that are heads of the name of the category.
      def heads
        return [] unless self.multiple_heads?
        self.head_trees.map do |tree|
          (head_node = tree.find_head_noun) && head_node.content
        end.compact
      end

      private
      def wrap_head_into_object(head)
        Syntax::Stanford::Converter.new(head).object_tree
      end
    end
  end
end
