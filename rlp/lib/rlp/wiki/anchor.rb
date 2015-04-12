# encoding: utf-8
module Rlp
  module Wiki
    # The data about anchors is kept in +anchor.csv+ and +anchro_occurrences.csv+
    # files. The first captuers the data about actual links to articles,
    # while the second captures the statistics of n-gram occurrences
    # in articles (with and without anchors).
    class Anchor < Model
      # The value of the anchor.
      # It is the (1) field in the +anchor_occurrence.csv+ file.
      field :value, :string, :index => :hash, :cache_size => 128 * 1024 * 1024

      # The number of times anchor ngram is used as a link.
      # It is the (2) field in the +anchor_occurrence.csv+ file.
      field :linked_count, :integer

      # The number of times anchor ngram is not used as a link.
      # It is the (4) field in the +anchor_occurrence.csv+ file.
      field :unlinked_count, :integer

      # The occurrences of the anchor pointing to different concepts.
      # They are found in the +anchor.csv+ file.
      has_many :occurrences

      validates_presence_of :value, :linked_count, :unlinked_count
      validates_numericality_of :linked_count, :unlinked_count

    end
  end
end
