require_relative 'cyc_filter'

module Mapping
  module Filter
    # Filters all collections that are ill defined, i.e. they don't have any
    # generalizations.
    class IllDefinedFilter < CycFilter
      # Remove terms that don't have generalizations.
      def apply(terms)
        terms.select{|t| cyc.genls(t) }
      end
    end
  end
end
