module Umbel
  class Serializer
    # Create file name based on class name and its constructor arguments. Try deserialize from this file, otherwise initialize object and serialize to file.
    def self.auto(klass, *arguments)
      name = create_name(klass, arguments)
      if File.exist? name
        File.open(name) do |file|
          return Marshal.load(file)
        end
      end

      object = klass.new(*arguments)
      File.open(name, 'w') do |output|
        Marshal.dump(object, output)
      end
      return object
    end

    private
    # Create file name based on class name and its constructor arguments.
    def self.create_name(klass, arguments)
      '%s-%s.marshal' % [klass.to_s, arguments.map { |argument| argument.gsub('/', '_') }.join(';')]
    end
  end
end
