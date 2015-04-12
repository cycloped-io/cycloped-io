require_relative 'cyc_filter'

module Mapping
  module Filter
    # Filter the results by part-of-speech of the corresponding word.
    class PosFilter < CycFilter
      ALLOWED_POSES = [:noun, :verb, :adjective]

      # Options
      # * :poses: - filters out the results to only include the terms that
      #   correspond to the specified parts of speech (:noun, :verb, :adjective)
      #   Only nouns are returned by default. Adjectives are not supported so far.
      # * :pos_service: - service used to check corresponding Part-of-Speech of
      #   the terms.
      def initialize(options)
        super
        @pos_service = options[:pos_service] ||  Service::PosService.new(Service::CycNameService.new(self.cyc))
        assign_allowed(:poses,[:noun],ALLOWED_POSES)
      end

      # Returns true if the term has the specified part-of-speech.
      def term_has_value?(term,pos)
        @pos_service.part_of_speech(term) == pos
      end
    end
  end
end
