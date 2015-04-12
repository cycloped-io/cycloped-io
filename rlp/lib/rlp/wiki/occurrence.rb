module Rlp
  module Wiki
    # The occurrences links unified anchor with one of the concepts
    # it links to. They are fetched from the in +anchor.csv+ file.
    class Occurrence < Model
      # The number of occurrences of the +anchor+ pointing to the +concept+.
      # It is the (3) field in the +anchor.csv+ file.
      field :count, :integer

      # The value (i.e. anchor value) of the occurrence with POS tags attached.
      # This data might be used to differentiate between various occurrences
      # with the same value.
      field :tagged_value, :string

      # The +concept+ this occurrence points to.
      # Its +wiki_id+ is the (2) field in the +anchor.csv+ file.
      has_one :concept

      # The anchor of this occurrence, that is the name of the link.
      has_one :anchor

      attr_accessor :measure

      validates_presence_of :count, :concept, :anchor
      validates_numericality_of :count
    end
  end
end
