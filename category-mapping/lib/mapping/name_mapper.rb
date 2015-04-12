module Mapping
  # Name mapper finds candidates for a given term name.
  # It may be configured to use only specific name discovery methods.
  class NameMapper
    ALLOWED_METHODS = [:exact, :label, :denotation]

    # Options:
    # * :name_service: - service used to query Cyc names
    # * :converter_factory: - factory used to convert names to Cyc format
    #   (e.g. New York (City) -> NewYork-City).
    # * :methods: - selected methods: :exact, :label, :denotation. The order is
    #   signitificant. [:exact, :denotation] by default.
    # * :return_all: - if set to true returns the result of the all
    #   methods that succeeded (true by default)
    def initialize(options={})
      @name_service = options[:name_service] || Service::CycNameService.new
      @cyc = options[:cyc] || @name_service.cyc
      @return_all = options.fetch(:return_all,true)

      @converter_factory = options[:converter_factory] || WikipediaNameConverter

      @find_methods = options[:methods] || [:exact, :denotation]
      if @find_methods == :all
        @find_methods = ALLOWED_METHODS
      else
        @find_methods.select! { |m| ALLOWED_METHODS.include?(m) }
      end

      @cache = Ref::WeakKeyMap.new
    end

    # Find cyc terms for a given concept name.
    # Returns an array, where first item is the method that succeeded and the
    # rest are candidate Cyc terms. The finding strategy is provided as options
    # to the constructor.
    def find_terms(name)
      return @cache[name] if @cache[name]
      results = []
      @find_methods.each do |method|
        result = __send__(:"find_#{method}", name)
        unless result.empty?
          results.concat(result)
          break unless @return_all
        end
      end
      if @return_all
        results = results.uniq
      end
      @cache[name] = results
    end

    private
    def find_exact(name)
      converter = @converter_factory.new(name)
      cyc_term = @name_service.find_by_term_name(converter.to_cyc)
      return [cyc_term] if cyc_term
      cyc_term = @name_service.find_by_term_name(converter.to_cyc(skip_qualifier: true))
      [cyc_term].compact
    rescue Cyc::CycError
      return []
    end

    def find_label(name)
      cyc_term = @name_service.find_by_label(name)
      [cyc_term].compact
    rescue Mapping::AmbiguousResult => ex
      return ex.results
    rescue Cyc::CycError
      return []
    end

    def find_denotation(name)
      @name_service.find_by_name(name)
    rescue Cyc::CycError
      return []
    end
  end
end
