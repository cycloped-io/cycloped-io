module Mapping
  class BidirectionalMap
    attr_accessor :key_to_values, :value_to_keys
    protected :key_to_values, :value_to_keys

    def initialize
      @key_to_values = Hash.new
      @value_to_keys = Hash.new
    end

    def add(key, value)
      (@key_to_values[key] ||=Set.new) << value
      (@value_to_keys[value] ||=Set.new) << key
    end

    def conflicts_keys(dictionary)
      self.class.conflicts(@key_to_values, dictionary.key_to_values)
    end

    def conflicts_values(dictionary)
      self.class.conflicts(@value_to_keys, dictionary.value_to_keys)
    end

    def difference_keys(dictionary)
      (@key_to_values.keys - dictionary.key_to_values.keys).map { |key| [key, @key_to_values[key]] }
    end

    def difference_values(dictionary)
      (@value_to_keys.keys - dictionary.value_to_keys.keys).map { |key| [key, @value_to_keys[key]] }
    end

    def intersection_keys(dictionary)
      (@key_to_values.keys & dictionary.key_to_values.keys).map { |key| [key, @key_to_values[key] ] }
    end

    def intersection_values(dictionary)
      (@value_to_keys.keys & dictionary.value_to_keys.keys).map { |key| [key, @value_to_keys[key] ] }
    end

    def keys_size
      @key_to_values.size
    end

    def values_size
      @value_to_keys.size
    end

    private

    def self.conflicts(first, second)
      intersection = first.keys & second.keys
      intersection.reject{ |key| first[key]==second[key] }.
        map { |key| [key, first[key], second[key]] }
    end
  end
end
