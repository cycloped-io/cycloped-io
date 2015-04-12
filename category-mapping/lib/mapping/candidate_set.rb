module Mapping
  class CandidateSet
    def initialize
      @map = {}
    end

    def add(name,candidates)
      @map[name] = candidates unless @map.has_key?(name)
    end

    def size
      @map.size
    end

    def name(index=0)
      self.all_names[index]
    end

    def all_names
      @map.keys
    end

    def full_name
      self.all_names.join(";")
    end

    def candidates(index=0)
      self.all_candidates[index]
    end

    def all_candidates
      @map.values
    end

    def empty?
      @map.empty?
    end

    def multiply_candidates
      multiply_collections(@map.values)
    end

    def each
      if block_given?
        @map.each do |name,candidates|
          yield name,candidates
        end
      else
        enum_for(:each)
      end
    end

    private
    def multiply_collections(array,start_index=0,partial_result=nil)
      if start_index == 0
        partial_result = []
        array[0].each do |value|
          partial_result << [value]
        end
        multiply_collections(array,start_index+1,partial_result)
      else
        new_result = []
        array[start_index].each do |value|
          partial_result.each do |tuple|
            new_result << tuple + [value]
          end
        end
        if start_index == array.size - 1
          new_result
        else
          multiply_collections(array,start_index+1,new_result)
        end
      end
    end
  end
end
