module Rlp
  module Wiki
    class Translation < Model
      # The language of the translation.
      # It is the (2) field in the +translation.csv+ file.
      field :language, :string

      # The value of the translation, that is its string representation.
      # It is the (3) field in the +translation.csv+ file.
      field :value, :string, :index => :hash

      # The page assigned to the translation.
      # The +wiki_id+ of page is the (1) field in the +translation.csv+ file.
      has_one :page, :polymorphic => true

      validates_presence_of :language, :value, :page

      # Default string representation of the translation.
      def to_s
        "#{self.value} (#{self.language})"
      end
    end
  end
end
