module Compound
  class PatternBuilder
    SUBS = {
      numbers: %w{N M L K},
      words: %w{X Y Z V}
    }

    def build(name,matches,max_order=3)
      if block_given?
        (1..max_order).each do |order|
          matches.combination(order) do |tuples|
            next if tuples.any?{|prefix,_,suffix| prefix.empty? && suffix.empty? }
            sorted_tuples = tuples.sort_by{|prefix,_,_| prefix.length }
            fragments = []
            @number_order = 0
            @name_order = 0
            offset = 0
            sorted_tuples.each.with_index do |(prefix,match,suffix),index|
              prefix_match = name[offset..-1].match(/^#{Regexp.escape(prefix[offset..-1])}/) rescue break
              break unless prefix_match
              fragments << prefix[offset..-1]
              fragments << substitute(match)
              suffix_match = name.match(/#{Regexp.escape(suffix)}$/)
              offset = suffix_match.begin(0)
            end
            fragments << name[offset..-1]
            if fragments.size == order * 2 + 1
              yield(fragments.join(""),order)
            end
          end
        end
      else
        enum_for(:build,name,matches,max_order)
      end
    end

    private
    def substitute(word)
      if number?(word)
        @number_order += 1
        SUBS[:numbers][@number_order - 1]
      else
        @name_order += 1
        SUBS[:words][@name_order - 1]
      end
    end

    def number?(word)
      word =~ /^\d+$/
    end
  end
end
