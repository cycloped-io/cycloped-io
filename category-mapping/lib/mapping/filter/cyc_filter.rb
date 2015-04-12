module Mapping
  module Filter
    # Base class used to filter results of Cyc queries.
    class CycFilter
      attr_reader :cyc

      def initialize(options={})
        @options = options
        @cyc = @options[:cyc] || Cyc::Client.new
      end

      # Apply the filter to the +terms+.
      def apply(terms)
        if @allowed == :all
          terms
        else
          terms.select do |term|
            @allowed.any? do |value|
              term_has_value?(term,value)
            end
          end
        end
      end

      protected
      # Assing allowed values of the filtered feature.
      def assign_allowed(name,default,allowed_values)
        @allowed = @options.fetch(:allowed,default)
        @allowed.select!{|p| allowed_values.include?(p) } unless @allowed == :all
      end
    end
  end
end
