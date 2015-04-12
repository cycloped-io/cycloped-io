require_relative 'mapping_service'

module Mapping
  module Service
    class ArticleMappingService < MappingService
      # The options that have to be provided to the category mapping service:
      # * :term_provider: - service used to provide candidate terms for
      #   categories and articles
      # * :context_provider: - service used to provide context for the mapped
      #   category
      # * :cyc: - Cyc client
      # Optional:
      # * :verbose: - if set to true, diagnostic messages will be send to the
      #   reporter
      # * :reporter: - service used to print the messages
      def initialize(options)
        @term_provider = options[:term_provider]
        @context_provider = options[:context_provider]
        @cyc = options[:cyc]
        @verbose = options[:verbose]
        @talkative = options[:talkative]
        @reporter = options[:reporter] || Reporter.new
      end

      # Returns a row with the article name supplemented with values of contextual
      # support for a given article - term mapping.
      def candidates_for_article(article)
        candidate_set = @term_provider.article_candidates(article)
        result = [article.name]
        report(article.name.hl(:blue))
        return result if candidate_set.empty?
        candidate_set.candidates.each do |term|
          parent_candidates = related_category_candidates(@context_provider.categories_for(article).uniq)
          genus_candidates = [@term_provider.genus_proximum_candidates(article)]
          type_candidates = related_type_candidates([article])
          parentheses_candidates = [@term_provider.parentheses_candidates(article)]
          counts = []
          counts.concat(number_of_matched_candidates(parent_candidates,term,article.name){|t,c| @cyc.with_any_mt{|cyc| cyc.isa?(t,c) } || @cyc.genls?(t,c) })
          counts.concat(number_of_matched_candidates(genus_candidates,term,genus_candidates.first.full_name){|t,c| @cyc.with_any_mt{|cyc| cyc.isa?(t,c) } || @cyc.genls?(t,c) })
          counts.concat(number_of_matched_candidates(type_candidates,term,"DBPEDIA_TYPE"){|t,c| @cyc.genls?(t,c) || @cyc.genls?(c,t) })
          counts.concat(number_of_matched_candidates(parentheses_candidates,term,parentheses_candidates.first.full_name){|t,c| @cyc.with_any_mt{|cyc| cyc.isa?(t,c) } || @cyc.genls?(t,c) })
          positive = counts.map.with_index{|e,i| e if i % 2 == 0 }.compact.inject(:+)
          negative = counts.map.with_index{|e,i| e if i % 2 != 0 }.compact.inject(:+)
          report do |reporter|
            if positive > 0
              count_str = "  %-20s p:%i/%i,g:%i/%i,t:%i/%i,r:%i/%i -> %i/%i/%.1f" %
                [term.to_ruby,*counts,positive,positive+negative,(positive.to_f/(positive+negative)*100)]
              reporter.call(count_str.hl(:green))
            else
              reporter.call("  #{term.to_ruby}".hl(:red))
            end
          end
          result.concat([term.id,term.to_ruby.to_s,positive,positive+negative])
        end
        result
      end
    end
  end
end
