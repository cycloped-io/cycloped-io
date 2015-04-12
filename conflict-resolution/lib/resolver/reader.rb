module Resolver
  class Partition
    attr_reader :support

    # * +support+ - support assigned to the partition
    def initialize(support)
      @support = support
      @terms = {}
    end

    def []=(term,support)
      @terms[term] = support
    end

    def size
      @terms.size
    end

    def each
      if block_given?
        @terms.each do |term,support|
          yield term,support
        end
      else
        enum_for(:each)
      end
    end

    def inspect
      "Partition[#{@size}:#{@support}]"
    end

    def to_s
      "Partition: #{@terms.keys.join(", ")}"
    end
  end

  class Reader
    def initialize(name_service=nil)
      @name_service = name_service
    end

    def extract_partitions(row,head_fields=1)
      head = row.shift(head_fields)
      partitions = []
      row.each do |element|
        case element
        when "P"
          partitions << []
        when /^(\d+(\.\d+)?|\d+(\.\d+)?e-?\d+)$/
          partitions.last << element.to_f
        else
          partitions.last << element
        end
      end
      object_partitions = partitions.map{|p| Partition.new(p.first) }
      partitions.zip(object_partitions).each do |elements,partition|
        elements[1..-1].each_slice(3) do |cyc_id,cyc_name,support|
          if @name_service
            entry = @name_service.find_by_id(cyc_id)
          else
            entry = [[cyc_id,cyc_name]]
          end
          partition[entry] = support
        end
      end
      [head,object_partitions]
    end
  end
end
