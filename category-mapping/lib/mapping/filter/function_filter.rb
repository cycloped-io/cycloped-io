module Mapping
  module Filter
    class FunctionFilter
      def apply(terms)
        terms.reject{|t| t.to_ruby.to_s =~ /Fn$/ }
      end
    end
  end
end
