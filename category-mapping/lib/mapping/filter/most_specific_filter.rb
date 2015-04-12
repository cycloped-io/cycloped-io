require_relative 'cyc_filter'

module Mapping
  module Filter
    # Filters all collections that are subsumed by other collections in the set.
    class MostSpecificFilter < CycFilter
      # Remove terms that are generalizations of other terms.
      def apply(terms)
        allowed_terms = cyc.min_cols(->() { "'" + terms.to_cyc(true) }) || []
        terms.select{|t|  allowed_terms.include?(t.to_ruby) }
      end
    end
  end
end
