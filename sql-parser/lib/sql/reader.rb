# encoding: utf-8
require 'progress'

module SQL
  class Reader
    attr_writer :chunk_size

    CHUNK_SIZE = 2 ** 24

    def initialize(input,schema_factory=nil,parser_factory=nil)
      @input = input
      @schema_factory = schema_factory || SchemaParser
      @parser_factory = parser_factory || InsertParser
    end

    def each_tuple
      unless block_given?
        return enum_for(:each_tuple)
      end
      schema = @schema_factory.new.parse(@input)
      parser = @parser_factory.new(schema)
      @input.pos = 0
      bytes_read = 0
      Progress.start(@input.size)
      while(!@input.eof?) do
        begin
          contents = @input.read(chunk_size)
          last_position = -1
          parser.parse(contents) do |data,hash|
            yield hash
            last_position = data.end(0)
          end
          if last_position == -1
            delta = chunk_size / 2
          else
            delta = last_position
          end
          bytes_read += delta
          Progress.step(delta)
          @input.pos = bytes_read
        rescue Interrupt => ex
          puts
          break
        end
      end
      Progress.stop
    end

    def chunk_size
      @chunk_size || CHUNK_SIZE
    end
  end
end
