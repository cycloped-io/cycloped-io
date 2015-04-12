require_relative 'all'

module Mapping
  module Filter
    class Factory
      # Options for the factory:
      # * :cyc: - cyc client instance
      # * :black_list: - black list of Cyc terms
      def initialize(options)
        @cyc = options[:cyc] || Cyc::Client.new
        @black_list = options[:black_list] || []
      end

      # Returns a list of filters for the given +configuration+ string.
      # The configuration string is a list of codes separated by colons (e.g.
      # a:b:c). The following codes are valid:
      # * c - collection filter
      # * c|i - collection or individual filter
      # * n - noun filter
      # * s - most specific filter
      # * r - rewrite of filter
      # * l - first letter lower case filter
      # * f - function (Fn$) filter
      # * b - black list filter
      def filters(configuration)
        (configuration || "").split(":").inject([]) do |result,code|
          case code
          when "c"
            result << collection_filter(@cyc)
          when "c|i"
            result << collection_or_individual_filter(@cyc)
          when "n"
            result << noun_filter(@cyc)
          when "s"
            result << most_specific_filter(@cyc)
          when "r"
            result << rewrite_of_filter(@cyc)
          when "l"
            result << lower_case_filter
          when "f"
            result << function_filter
          when "b"
            result << black_list_filter(@black_list)
          end
          result
        end
      end

      private
      def lower_case_filter
        LowerCaseFilter.new
      end

      def noun_filter(cyc)
        PosFilter.new(cyc: cyc)
      end

      def collection_filter(cyc)
        TypeFilter.new(cyc: cyc,allowed: [:collection])
      end

      def collection_or_individual_filter(cyc)
        TypeFilter.new(cyc: cyc,allowed: [:collection,:individual])
      end

      def most_specific_filter(cyc)
        MostSpecificFilter.new(cyc: cyc)
      end

      def rewrite_of_filter(cyc)
        RewriteOfFilter.new(cyc: cyc)
      end

      def function_filter
        FunctionFilter.new
      end

      def black_list_filter(black_list)
        BlackListFilter.new(black_list)
      end
    end
  end
end
