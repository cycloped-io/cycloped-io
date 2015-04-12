require 'cycr'
require 'set'

module Rlp
  module Wiki
    # The Cyc term which is be used to establish correspondence
    # between Wiki concepts and Cyc terms. It might be an
    # individual or a collection. Most of the its API should be
    # build as proxy to Cyc ontology.
    class Term < Model
      # The name of the term. Might be similar to Ruby table
      # in case of non-atomic terms.
      field :name, :string, :index => :hash

      # The unique id of the term as used in the Cyc Semantic Web service.
      field :cyc_id, :string, :index => :hash

      # The kind of the term: collection/individual/(relation?)
      field :kind, :object

      # The synonym of the term in Wiki (if exists).
      has_one :synonym, :class_name => "Rlp::Wiki::Concept"

      # The concepts that belong to this term - they might be connected
      # via genls AND isa relation. So far it is not determined.
      has_many :concepts

      # The kinds that are linked with this term.
      has_many :kinds

      validates_presence_of :name, :cyc_id
      validates_inclusion_of :kind, :in => [:collection, :individual]
    end
  end
end
