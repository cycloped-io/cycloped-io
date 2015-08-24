require 'ref'

module Mapping
  # This class is used to generate candidate Cyc terms for a given Wikipedia
  # category or article. It uses sophisticated name resolution strategy as
  # well as filtering of candidates that are not likely to be mapped to a given
  # category or article.
  class TermProvider
    def initialize(options={})
      @name_service = options[:name_service]
      @cyc = options[:cyc] || Cyc::Client.new(cache: true)
      @name_mapper = options[:name_mapper] || NameMapper.new(cyc: @cyc, name_service: @name_service)
      @simplifier_factory = options[:simplifier_factory] || Syntax::Stanford::Simplifier
      @candidate_set_factory = options[:candidate_set_factory] || CandidateSet

      @category_filters = options[:category_filters] || []
      @article_filters = options[:article_filters] || []
      @genus_filters = options[:genus_filters] || []

      @category_cache = Ref::WeakValueMap.new
      @article_cache = Ref::WeakValueMap.new
      @concept_types_cache = Ref::WeakValueMap.new
      @term_cache = Ref::WeakValueMap.new

      @nouns = Wiktionary::Noun.new
    end

    # Returns the candidate terms for the Wikipedia +category+.
    # The results is a CandidateSet.
    def category_candidates(category)
      return @category_cache[category] unless @category_cache[category].nil?
      candidates = candidates_for_name(singularize_name(category.name, category.head), @category_filters)
      if !candidates.empty?
        candidate_set = create_candidate_set(category.name,candidates)
      else
        candidate_set = candidate_set_for_syntax_trees(category.head_trees,@category_filters)
      end
      if candidate_set.empty?
        candidates = candidates_for_name(category.name, @category_filters)
        candidate_set = create_candidate_set(category.name,candidates) unless candidates.empty?
      end
      @category_cache[category] = candidate_set
    end

    # Returns the candidate terms for the Wikipedia +category+ using whole category name.
    # The results is a CandidateSet.
    def core_category_candidates(category)
      candidates = []
      singularize_name_nouns(category.name, category.head).each do |phrase|
        candidates.concat(candidates_for_name(phrase, @category_filters))

      end
      candidate_set = create_candidate_set(category.name,candidates.uniq)
    end

    # Return the candidate terms for a given +pattern+ which is exemplified
    # by the +representative+. The result is a CandidateSet.
    def pattern_candidates(pattern,representative)
      candidate_set_for_syntax_trees(representative.head_trees,@category_filters,pattern)
    end

    # Returns the candidate terms for the Wikipedia +article+.
    # The result is a CandidateSet.
    def article_candidates(article)
      return @article_cache[article] unless @article_cache[article].nil?
      candidates = candidates_for_name(article.name, @article_filters)
      if candidates.empty?
        candidates = candidates_for_name(remove_parentheses(article.name), @article_filters)
      end
      @article_cache[article] = create_candidate_set(article.name,candidates)
    end

    # Returns the candidates terms for the Wikipedia article genus proxima.
    # The result is a CandidateSet.
    def genus_proximum_candidates(concept)
      return @concept_types_cache[concept] unless @concept_types_cache[concept].nil?
      @concept_types_cache[concept] = candidate_set_for_syntax_trees(concept.types_trees, @genus_filters)
    end

    # Returns the candidates terms for the Wikipedia article type indicated in
    # parentheses.
    # The result is a CandidateSet.
    def parentheses_candidates(concept)
      type = type_in_parentheses(concept.name)
      if type.empty?
        candidates = []
      else
        candidates = candidates_for_name(type, @genus_filters)
      end
      create_candidate_set(type,candidates)
    end

    # Returns the term that exactly matches provided +cyc_id+. Returned as an
    # array.
    def term_candidates(cyc_id)
      return @term_cache[cyc_id] unless @term_cache[cyc_id].nil?
      @term_cache[cyc_id] = create_candidate_set("",[@name_service.find_by_id(cyc_id)])
    end

    # Return the candidates for the given syntax +trees+. The results are filtered
    # using the +filters+. If +pattern+ is given, it is used to filter out too
    # simplified names based on the +trees+. Do not break on first hit.
    def all_candidate_set_for_syntax_tree(tree)
      filters=@genus_filters

      names = @simplifier_factory.new(tree).simplify.to_a
      candidate_set = @candidate_set_factory.new
      head_node = tree.find_head_noun
      if head_node
        head = head_node.content
        names.each do |name|
          simplified_names = singularize_name_nouns(name, head)
          simplified_names.each do |simplified_name|
            candidates = candidates_for_name(simplified_name, filters)
            unless candidates.empty?
              candidate_set.add(name,candidates)
              # break
            end
          end
        end
      end
      candidate_set
    end

    # Singularize using Wiktionary data
    def singularize_name_nouns(name, head)
      names = [name]
      singularized_heads = @nouns.singularize(head)
      if not singularized_heads.nil?
        singularized_heads.each do |singularized_head|
          names << name.sub(/\b#{Regexp.quote(head)}\b/, singularized_head)
        end
      end
      names
    end

    # Return candidates for the given +name+ and apply the +filters+ to the
    # result.
    def candidates_for_name(name, filters)
      candidates = @name_mapper.find_terms(name)
      filters.inject(candidates) do |terms, filter|
        filter.apply(terms)
      end
    end

    # Create a candidate set for single group of candidates.
    def create_candidate_set(name,candidates)
      result = @candidate_set_factory.new
      result.add(name,candidates) unless candidates.empty?
      result
    end

    # Create empty candidate set.
    def create_empty_candidate_set
      @candidate_set_factory.new
    end

    private
    # Return the candidates for the given syntax +trees+. The results are filtered
    # using the +filters+. If +pattern+ is given, it is used to filter out too
    # simplified names based on the +trees+.
    def candidate_set_for_syntax_trees(trees, filters,pattern=nil)
      candidate_set = @candidate_set_factory.new
      trees.each do |tree|
        names = @simplifier_factory.new(tree).simplify.to_a
        if pattern
          names.select! do |name|
            # Pattern won't match too specific name, e.g.
            # "X almumni" does not match /University alumni/
            pattern =~ /#{name}/
          end
        end
        head_node = tree.find_head_noun
        next unless head_node
        head = head_node.content
        names.each do |name|
          simplified_name = singularize_name(name, head)
          candidates = candidates_for_name(simplified_name, filters)
          unless candidates.empty?
            candidate_set.add(name,candidates)
            break
          end
        end
      end
      candidate_set
    end





    # Should be moved elswhere.
    def singularize_name(name, head)
      if head.respond_to?(:singularize)
        singularized_head = head.singularize
        if singularized_head.size==0
          singularized_head=head
        end
        name.sub(/\b#{Regexp.quote(head)}\b/, singularized_head)
      else
        name
      end
    end



    def remove_parentheses(name)
      return name if name !~ /\(/ || name =~ /^\(/
      name.sub(/\([^)]*\)/,"").strip
    end

    def type_in_parentheses(name)
      type = name[/\([^)]*\)/]
      type ? type[1..-2] : ""
    end


  end
end
