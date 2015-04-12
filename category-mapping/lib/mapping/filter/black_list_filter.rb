module Mapping
  module Filter
    # Filters all that are on the blacklist
    class BlackListFilter
      # Black list of terms (in the form of Ruby symbols/arrays).
      def initialize(black_list)
        @black_list = black_list
      end

      # Remove terms that are on the black_list.
      def apply(terms)
        terms.reject{|t| @black_list.include?(t.to_ruby) }
      end
    end
  end
end
