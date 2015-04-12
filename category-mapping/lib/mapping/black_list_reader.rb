require 'set'

module Mapping
  class BlackListReader
    def initialize(path)
      @path = path
    end

    def read
      return [] if @path.nil?
      return @blacklist if @blacklist
      @blacklist = Set.new(File.readlines(@path).map(&:chomp).map(&:to_sym))
    end
  end
end
