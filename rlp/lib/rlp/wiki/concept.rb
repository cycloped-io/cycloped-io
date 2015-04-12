# encoding: utf-8
require 'set'

module Rlp
  module Wiki
    # The concepts are kept in +page.csv+ file and their type
    # is set to (1) (the type is the (3) field in the file).
    class Concept < Page
      SYMBOL_RE = /^\p{P}+$/

      # The semantic category (genus proximum) identified in the first sentence.
      field :semantic_category, :string, :index => :hash

      # The kind of page.
      # This might be one of:
      # * +nil+ - the initial status
      # * +:list+ - list page
      # * +:disambiguation+ - disambiguation page
      # * +:other+ - index, outline, glossary, data page
      field :status, :object

      # The definition (the first sentence) of the concept. Taken from DBpedia.
      field :definition, :string

      # The definition tagged with Stanford tagger.
      field :tagged_definition, :string

      # A vector of categories which are valid for the concept.
      # These should be semantic categories, that the concept belongs to.
      field :valid_categories, :object

      # List of definitions extracted from first sentence.
      field :types, :object

      # The Cyc term derived from the DBpedia infobox mapping.
      has_one :dbpedia_type, :class_name => "Rlp::Wiki::Term"

      # The parent concept that is supposed to be the semantic
      # category of this concept. It should appear in the definition
      # of the concept.
      has_one :parent, :class_name => "Rlp::Wiki::Concept"

      # The categories this concept belongs to.
      # Their +wiki_ids+ are the (1) field in the +cagtegorylink.csv+ file.
      has_many :categories

      # The concepts linking to this concept.
      # Their +wiki_ids+ are the (1) field in the +pagelink.csv+ file.
      has_many :linking_concepts, :class_name => "Rlp::Wiki::Concept"

      # The concepts this concept links to.
      # Their +wiki_ids+ are the (2) field in the +pagelink.csv+ file.
      has_many :linked_concepts, :class_name => "Rlp::Wiki::Concept"

      # The text values used in links pointing to this concept.
      # They are stored in the +anchor.csv+ file.
      has_many :occurrences

      # The terms this concept belongs to in Cyc. This might be isa OR genls
      # relation. Its nature is not determined.
      has_many :terms

      # The categories which are equivalent to the concept.
      # Its +wiki_id+ is the (1) field in the +equivalence.csv+ file.
      # In rare cases there are many categories that are equivalent to one
      # article.
      has_many :eponymous_categories, :class_name => "Rlp::Wiki::Category"


      # DBpedia classes are DBpedia classes (types) of the concept.
      #has_many :dbpedia_classes

      # Returns the most popular target of anchors with given label.
      def self.find_by_label(label)
        anchor = Anchor.find_by_value(label)
        return nil unless anchor
        occurrence = anchor.occurrences.sort_by{|o| -o.count }.first
        return nil unless occurrence
        occurrence.concept
      end

      # Indicates if article is regular (not list, dissambiguation page, etc.)
      def regular?
        status.nil?
      end

      def types_trees
        return [] unless types
        types.map do |prefix, parse|
          wrap_head_into_object(parse)
        end.compact
      end

      private
      def wrap_head_into_object(head)
        Syntax::Stanford::Converter.new(head).object_tree
      end
    end
  end
end
