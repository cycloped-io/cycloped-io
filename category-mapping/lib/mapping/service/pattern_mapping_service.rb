require_relative 'mapping_service'

module Mapping
  module Service
    class PatternMappingService < MappingService

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
        @sample_size = options[:sample_size]
      end

      def candidates_for_pattern(pattern,head,category_ids,support)
        representative_id = category_ids.find do |category_wiki_id|
          category = Category.find_by_wiki_id(category_wiki_id)
          next unless category.plural? && category.regular?
          category.head == head
        end
        return [] if representative_id.nil?
        representative = Category.find_by_wiki_id(representative_id)
        candidate_set = @term_provider.pattern_candidates(pattern,representative)
        row = [pattern,candidate_set.full_name,support]
        report(pattern.hl(:blue))
        if candidate_set.size > 1
          report(candidate_set.all_candidates.to_s.hl(:purple))
          candidates = @multiplier.multiply(candidate_set)
          report(candidates.to_s.hl(:purple))
        else
          candidates = candidate_set.candidates
        end
        if candidates && !candidates.empty?
          # related candidate sets
          parents = Set.new
          children = Set.new
          articles = Set.new
          category_ids.sample(@sample_size).each do |category_wiki_id|
            category = Category.find_by_wiki_id(category_wiki_id)
            parents.merge(@context_provider.parents_for(category))
            children.merge(@context_provider.children_for(category))
            articles.merge(@context_provider.articles_for(category))
          end
          parent_candidate_sets = related_category_candidates(parents.to_a)
          child_candidate_sets = related_category_candidates(children.to_a)
          instance_candidate_sets = related_article_candidates(articles.to_a)
          type_candidate_sets = related_type_candidates(articles.to_a)
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
