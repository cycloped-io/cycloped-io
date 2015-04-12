module Mapping
  class CandidateMultiplier
    def initialize(options)
      @merger = options[:merger]
      @black_list = options[:black_list]
      @name_service = options[:name_service]
    end

    def multiply(candidate_set)
      new_candidates = []
      candidate_set.multiply_candidates.each do |tuple|
        new_candidates.concat(@merger.merge(*tuple))
      end
      candidates = new_candidates.reject do |candidate|
        if Array === candidate
          candidate.flatten.any?{|e| @black_list.include?(e) }
        else
          @black_list.include?(candidate)
        end
      end.map{|c| @name_service.convert_ruby_term(c) }
    end
  end
end
