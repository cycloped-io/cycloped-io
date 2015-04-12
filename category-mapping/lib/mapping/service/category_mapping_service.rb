require_relative 'mapping_service'

module Mapping
  module Service
    class CategoryMappingService < MappingService

      # The options that have to be provided to the category mapping service:
      # * :term_provider: - service used to provide candidate terms for
      #   categories and articles
      # * :context_provider: - service used to provide context for the mapped
      #   category
      # * :cyc: - Cyc client
      # * :multiplier: - service used to find most specific generalizations for
      #   categories with multiple heads
      # Optional:
      # * :verbose: - if set to true, diagnostic messages will be send to the
      #   reporter
      # * :reporter: - service used to print the messages
      def initialize(options)
        @term_provider = options[:term_provider]
        @context_provider = options[:context_provider]
        @cyc = options[:cyc]
        @multiplier = options[:multiplier]
        @verbose = options[:verbose]
        @talkative = options[:talkative]
        @reporter = options[:reporter] || Reporter.new
      end

      # Returns a row with the category name, the names that were used to find
      # the candidates and Cyc candidates supplemented with values of contextual
      # support for a given category - term mapping.
      def candidates_for_category(category)
        candidate_set = @term_provider.category_candidates(category)
        row = [category.name,candidate_set.full_name]
        report(category.name.hl(:blue))
        if candidate_set.size > 1
          report(candidate_set.all_candidates.to_s.hl(:purple))
          candidates = @multiplier.multiply(candidate_set)
          report(candidates.to_s.hl(:purple))
        else
          candidates = candidate_set.candidates
        end
        if candidates && !candidates.empty?
          # related candidate sets
          parent_candidate_sets = related_category_candidates(@context_provider.parents_for(category).uniq)
          child_candidate_sets = related_category_candidates(@context_provider.children_for(category).uniq)
          articles = @context_provider.articles_for(category).uniq
          instance_candidate_sets = related_article_candidates(articles)
          type_candidate_sets = related_type_candidates(articles)
          # matched relations computation
          candidates.each do |term|
            counts = []
            counts.concat(number_of_matched_candidates(parent_candidate_sets,term,candidate_set.full_name){|t,c| @cyc.genls?(t,c) })
            counts.concat(number_of_matched_candidates(child_candidate_sets,term,candidate_set.full_name){|t,c| @cyc.genls?(c,t) })
            counts.concat(number_of_matched_candidates(instance_candidate_sets,term,candidate_set.full_name){|t,c| @cyc.with_any_mt{|cyc| cyc.isa?(c,t) } })
            # Alcohol case
            counts.concat(number_of_matched_candidates(type_candidate_sets,term,"DBPEDIA_TYPE"){|t,c| @cyc.genls?(t,c) || @cyc.genls?(c,t) ||
                          @cyc.isa?(t,c) || @cyc.isa?(c,t) })
            positive = counts.map.with_index{|e,i| e if i % 2 == 0 }.compact.inject(0){|e,s| e + s }
            negative = counts.map.with_index{|e,i| e if i % 2 != 0 }.compact.inject(0){|e,s| e + s }
            report do |reporter|
              if positive > 0
                count_string = "  %-20s p:%i/%i,c:%i/%i,i:%i/%i,t:%i/%i -> %i/%i/%.1f" %
                  [term.to_ruby,*counts,positive,positive+negative,(positive/(positive+negative).to_f*100)]
                reporter.call(count_string.hl(:green))
              else
                reporter.call("  #{term.to_ruby}".hl(:red))
              end
            end
            row.concat([term.id,term.to_ruby,positive,positive+negative])
          end
        end
        row
      end
    end
  end
end
