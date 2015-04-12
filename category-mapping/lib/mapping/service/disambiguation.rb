require 'set'

module Mapping
  module Service
    # This service is responsible for implementing the local disambiguation heuristic.
    # This heuristic has 2 rules:
    # * child category with missing disambiguation inherits from category with
    #   same syntactic head
    # * child category with missing damb. inherits from category with compatible
    #   cyc term (determined via genls)
    class Disambiguation
      def initialize(category_mapping,output,verbose,name_service)
        @category_mapping = category_mapping
        @output = output
        @verbose = verbose
        @name_service = name_service
        @visited = Set.new
      end

      def recursive_disambiguation(category_name)
        category = Category.find_by_name(category_name)
        mapping = @category_mapping[category_name]
        return mapping if @visited.include?(category_name)
        @visited << category_name
        # remove mapped name fragment
        candidate_terms = mapping.map{|c| @name_service.find_by_id(c.cyc_id) }
        best_results = {}
        output_tuple = [category_name,"_INHERITED_"]
        category.parents.each do |parent|
          next if !parent.regular? || !parent.plural?
          parent_mapping = @category_mapping[parent.name]
          if parent_mapping.inject(0){|s,c| s + c.positive} == 0 && !@visited.include?(parent.name)
            # should have changed
            parent_mapping = recursive_disambiguation(parent.name)
          end
          parent_mapping.each do |parent_candidate|
            next if parent_candidate.positive == 0
            parent_term = @name_service.find_by_id(parent_candidate.cyc_id)
            # heuristic criterias
            next if !heads_match?(category,parent) && !terms_match?(candidate_terms,parent_term)
            if higher_probability?(parent_candidate,best_results)
              best_results[parent_candidate.cyc_id] = [parent_candidate,parent.name]
            end
          end
          best_results.each do |cyc_id,(candidate,parent_name)|
            output_tuple.concat([candidate.cyc_id,candidate.cyc_name,candidate.positive,candidate.total])
          end
          if @verbose
            if output_tuple.size > 2
              puts category.name.hl(:purple)
              best_results.sort_by{|_,(c,_)| - c.probability }.each do |cyc_id,(candidate,parent_name)|
                puts "* #{candidate.cyc_name.hl(:green)} : #{parent_name} : #{candidate.probability}"
              end
            end
          end
        end
        if output_tuple.size > 2
          unified = {}
          output_tuple[2..-1].each_slice(4){|id,name,positive,total| unified[[id,name]] ||= [0,0]; unified[[id,name]][0] += positive; unified[[id,name]][1] += total }

          @output << output_tuple[0..1] + unified.map{|(id,name),(positive,total)| [id,name,positive,total] }.flatten(1)
          @category_mapping[category_name] = unified.map{|(id,name),(positive,total)| Candidate.new(id,name,positive,total) }
        end
        @category_mapping[category_name]
      end

      private
      def heads_match?(category,parent)
        (parent.head || "").downcase == (category.head || "").downcase
      end

      def terms_match?(candidate_terms,parent_term)
        candidate_terms.any?{|c| @name_service.cyc.genls?(c,parent_term) }
      end

      def higher_probability?(candidate,best_results)
        best_results[candidate.cyc_id].nil? || best_results[candidate.cyc_id][0].probability < candidate.probability
      end
    end
  end
end
