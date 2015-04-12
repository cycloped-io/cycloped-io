module Rlp
  module Wiki
    # This class represents the infoboxes found in Wikipedia
    # articles. Most of them are good indicators of the
    # semantic category of the article.
    class Infobox < Model
      # The name of the infobox.
      field :name, :string, :index => :hash

      # The DBpedia class given infobox is mapped to.
      field :klass, :string, :index => :hash

      # The term given infobox is mapped to
      has_one :term

      # The concepts that include this type of infobox.
      has_many :concepts
    end
  end
end
