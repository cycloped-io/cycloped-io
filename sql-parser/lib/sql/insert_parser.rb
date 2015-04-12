# encoding: utf-8

module SQL
  class InsertParser
    REGEXPS = {
      string: %{'(?:\\\\\\\\|\\\\'|[^'])*'},
      integer: %{\\d+},
      timestamp: %{'\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}'},
      float: %{\\d+\\.\\d+}
    }
    NULL = "NULL"

    # Specify the table schema. The specification contains
    # of pairs: field name - field type. Accepted types are as follows:
    # * :string
    # * :integer
    # * :timestamp
    def initialize(schema)
      @schema = schema
      @regexp = Regexp.new(build_regexp(schema))
    end

    # Parse the input according to the schema. The method yields each matched
    # tuple.
    def parse(input)
      input.scan(@regexp) do |match|
        matched_regexp = $~
        hash = Hash[@schema.map do |field,type|
          value = matched_regexp[field]
          if value == NULL
            [field,nil]
          else
            case type
            when :integer,:float
              [field,value]
            when :string,:timestamp
              value = value[1..-2].gsub("\\\\","\\").gsub("\\'","'").force_encoding("utf-8")
              [field,value]
            end
          end
        end]
        yield matched_regexp,hash
      end
    end

    private
    def build_regexp(schema)
      "\\(" + schema.map do |name,type|
        "(?<#{name}>(?:NULL|#{REGEXPS[type]}))"
      end.join(",") + "\\)"
    end
  end
end
