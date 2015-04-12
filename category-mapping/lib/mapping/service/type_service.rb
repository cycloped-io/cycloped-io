module Mapping
  module Service
    class TypeService
      def initialize(cyc=Cyc::Client.new)
        @cyc = cyc
      end

      # Returns the abstract type of the term:
      # * :collection:
      # * :individual:
      # * :microtheory:
      # * :relation:
      def term_type(term)
        if @cyc.isa?(term,:Collection)
          return :collection
        elsif @cyc.isa?(term,:Microtheory)
          return :microtheory
        elsif @cyc.isa?(term,:Relation)
          return :relation
        elsif @cyc.isa?(term,:Individual)
          return :individual
        end
      end
    end
  end
end
