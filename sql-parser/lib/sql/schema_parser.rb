# encoding: utf-8

module SQL
  class SchemaParser
    TYPES = %{int|varbinary|timestamp|enum|tinyblob|bigint|tinyint|double}
    SCHEMA_REGEXP = 
      /CREATE\sTABLE\s`(?<name>\w+)`\s*\(\s*
      (?<fields>(`\w+`\s(?:#{TYPES})(\([^)]*\))?[^,]*,\s*)+)
      (?<keys>(?:((UNIQUE|PRIMARY)\s)?KEY\s(`\w+`\s)?\((?:`\w+`,?)+\),?\s*)*)
      \)(?<engine>[\w\s=]*);/mx
    FIELDS_REGEXP =
      /`(?<name>\w+)`\s(?<type>#{TYPES})(\([^)]*\))?[^,]*,?/
    TYPE_MAPPING = Hash.new(:string).merge({
      "int" => :integer,
      "tinyint" => :integer,
      "timestamp" => :timestamp,
      "bigint" => :integer,
      "double" => :float
    })

    # Parses input in order to extract the SQL schema.
    # The input might be a string or an IO object. In the second case the
    # +limit+ parameter is used to restrict the number of bytes read in order to
    # find the schema.
    def parse(input,limit=4096)
      if input.respond_to?(:read)
        input = input.read(limit)
      end
      result = []
      matched = SCHEMA_REGEXP.match(input)
      raise "Schema not found." if matched.nil?
      matched[:fields].scan(FIELDS_REGEXP){|match| result << [$~[:name].to_sym,TYPE_MAPPING[$~[:type]]]}
      Hash[result]
    end
  end
end
