require_relative 'reference_concept'

module Umbel
  class SuperType < ReferenceConcept
    def initialize(name)
      super(name, '', [])
    end
  end
end
