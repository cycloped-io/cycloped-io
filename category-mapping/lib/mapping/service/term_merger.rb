module Mapping
  module Service
    # This service is used to find a most specific generalization for two or
    # more Cyc collections.

    class TermMerger
      def initialize(options={})
        @cyc = options[:cyc] || Cyc::Client.new(cache: true)
        @cyc.talk("(define col-with-count (col) (ret (list (length (all-genls col)) col)))")
      end

      # Returns the most specific generalization of term1 and term2.
      def merge(*terms)
        result = @cyc.mapcar(->(){ "#'col-with-count" }){|cyc| cyc.min_ceiling_cols ->() { "'(#{terms.map(&:to_cyc).join(" ")})" }}
        return [] unless result
        count = result.min{|(c1,_),(c2,_)| c2 <=> c1 }[0]
        result.select{|c,t| c == count }.map(&:last)
      end
    end
  end
end
