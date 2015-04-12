module Mapping
  module Service
    class MappingService
      class Reporter
        def call(message)
          puts message
        end
      end

      protected
      def report(string="")
        if block_given?
          if @verbose
            yield @reporter
          end
        else
          @reporter.call(string) if @verbose
        end
      end

      def verbose_report(string="")
        if block_given?
          if @talkative
            yield @reporter
          end
        else
          @reporter.call(string) if @talkative
        end
      end

      def related_category_candidates(categories)
        categories.select{|c| c.regular? && c.plural?}.map{|c| @term_provider.category_candidates(c) }.
          reject{|candidate_set| candidate_set.empty? }
      end

      def related_article_candidates(articles)
        articles.select{|a| a.regular? }.map{|a| @term_provider.article_candidates(a) }.reject{|candidate_set| candidate_set.empty? }
      end

      def related_type_candidates(articles)
        articles.select{|a| a.regular? && a.dbpedia_type }.map{|a| @term_provider.term_candidates(a.dbpedia_type.cyc_id) }
      end

      def number_of_matched_candidates(candidate_sets_for_related_terms,term,entity_name)
        candidate_sets_for_related_terms.map do |candidate_set|
          next if candidate_set.full_name.downcase.singularize == entity_name.downcase.singularize || candidate_set.all_candidates.flatten.empty?
          verbose_report{|r| r.call "#{candidate_set.full_name} -> #{candidate_set.all_candidates.flatten.join(",")}" }
          evidence = candidate_set.all_candidates.flatten.find{|candidate| yield(term,candidate) }
          if evidence
            verbose_report("#{entity_name.downcase.singularize} - #{candidate_set.full_name.downcase.singularize} - #{evidence.to_ruby}".hl(:yellow))
          end
          !!evidence
        end.compact.partition{|e| e }.map{|e| e.size }
      end
    end
  end
end
