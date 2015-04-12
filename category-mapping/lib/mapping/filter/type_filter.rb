require_relative 'cyc_filter'

module Mapping
  module Filter
    # Filter the results by part-of-speech of the corresponding word.
    class TypeFilter < CycFilter
      ALLOWED_TYPES = [:collection, :individual, :relation, :microtheory]

      # Options
      # * :types: - filters out the results to only include the specified
      #   Cyc general term types (:collection, :individual, :relation). Only
      #   collections are returned by default.
      # * :type_service: - service used to check type of the terms.
      def initialize(options)
        super
        @type_service = options[:type_service] ||  Service::TypeService.new(self.cyc)
        assign_allowed(:types,[:collection],ALLOWED_TYPES)
      end

      # Returns true if the term has the specified part-of-speech.
      def term_has_value?(term,type)
        @type_service.term_type(term) == type
      end
    end
  end
end
