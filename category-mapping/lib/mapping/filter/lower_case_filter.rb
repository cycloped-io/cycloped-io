# encoding: utf-8

module Mapping
  module Filter
    # This filter removes concepts that start with a lower case.
    class LowerCaseFilter
      def apply(terms)
        terms.reject{|t| t.to_s =~ /^\p{Ll}/ }
      end
    end
  end
end
