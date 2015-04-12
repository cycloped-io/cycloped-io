require 'active_model/naming'

module Mapping
  module Service
    class PosService
      def initialize(name_service=CycNameService.new)
        @name_service = name_service
      end

      # Returns generlaized part of speech of the term (:noun, :verb, :adjective or
      # nil).
      def part_of_speech(term)
        mappings = @name_service.labels(term)
        canonical_mapping = @name_service.canonical_label(term)
        if mappings.any?{|mapping| mapping =~ /^will\b/ }
          return :verb
        elsif mappings.any?{|m| m =~ /er$/ } && mappings.any?{|m| m =~ /est$/ }
          return :adjective
        elsif canonical_mapping && mappings.any?{|m| canonical_mapping.pluralize == m }
          return :noun
        end
      end
    end
  end
end
