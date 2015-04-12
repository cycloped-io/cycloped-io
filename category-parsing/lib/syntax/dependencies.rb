module Syntax
  class Dependencies
    attr_accessor :dependencies

    def initialize(dependencies)
      @dependencies = dependencies
    end

    def to_s
      @dependencies.to_s
    end
    
  end
end