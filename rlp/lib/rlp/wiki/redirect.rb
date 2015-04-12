module Rlp
  module Wiki
    # The redirects are the redirects fund in Wikipedia.
    # The +redirectTargetBySource.csv+ and +redirectSourcesByTarget.csv+ files
    # contain the mapping of redirects to their pages.
    class Redirect < Page
      # If not empty, this filed informs that the target is in different Wikipedia
      # instance.
      field :interwiki, :string

      # If not empty, this field indicates that the redirect points to a section
      # in the Wikipedia page rather than the whole page.
      field :fragment, :string

      # The page this redirect points to.
      has_one :page, :polymorphic => true
    end
  end
end
