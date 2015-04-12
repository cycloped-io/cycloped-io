# encoding: utf-8

module Compound
  class ProperNameExtractor
    def proper_names(name)
      if block_given?
        words = split_name(name)
        words.each.with_index do |word,index|
          next unless word =~ /^\p{Lu}/
          (words.size - index).times do |length|
            range = index..index+length
            yield(words[range].join(""),range) unless words[range.last] == " "
          end
        end
      else
        enum_for(:proper_names,name)
      end
    end

    private
    # Splits the name into words.
    def split_name(name)
      name.split(/(?<=\S)(?=\s)|(?<=\s)(?=\S)|\b/)
    end

  end
end
