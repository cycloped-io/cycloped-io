require 'concurrent'

module Mapping
  class ContextProvider
    MAX_COLLECTION_SIZE = 1000
    # Options:
    # * +rlp_services+ - services used to talk to remote RLP DBs.
    # * +pool_size+ - thread pool size
    def initialize(options={})
      @rlp_services = options.fetch(:rlp_services)
      pool_size = options.fetch(:pool_size,3)
      @pool = Concurrent::FixedThreadPool.new(pool_size)
      @timeout = 15
    end

    # Parents of the category accodring to wide context.
    def parents_for(category)
      from_eponymous = category.eponymous_concepts.map do |concept|
        concept.categories.to_a
      end.flatten
      (remote_counterparts(category,:parents,Rlp::Wiki::Category) + category.parents.to_a + from_eponymous).
        select{|c| c.regular? && c.plural? }
    end

    # Children of the category accodring to wide context.
    def children_for(category)
      (remote_counterparts(category,:children,Rlp::Wiki::Category) + category.children.to_a).
        select{|c| c.regular? && c.plural? }
    end

    # Articles of the category accodring to wide context.
    def articles_for(category)
      (remote_counterparts(category,:concepts,Rlp::Wiki::Concept) + category.concepts.to_a)
    end

    # Categories of the concept according to wide context.
    def categories_for(concept)
      from_eponymous = concept.eponymous_categories.map do |category|
        category.parents.to_a
      end.flatten
      (remote_counterparts(concept,:categories,Rlp::Wiki::Category) + concept.categories.to_a + from_eponymous).
        select{|c| c.regular? && c.plural? }
    end

    private
    def remote_counterparts(page,relation,related_class)
      translated_proxies(page,finder_name(page)).map do |proxy|
        Concurrent::Future.execute(executor: @pool) do
          if proxy.send(relation).size > MAX_COLLECTION_SIZE
            elements = proxy.send(relation)[0..MAX_COLLECTION_SIZE]
          else
            elements = proxy.send(relation)
          end
          elements.map do |related_proxy|
            related_proxy.translations.find{|t| t.language == "en" }
          end.compact.map{|t| remove_scope(t.value) }.map{|t| related_class.find_by_name(t) }.compact
        end
      end.map{|f| f.value(@timeout) }.compact.flatten
    end

    def translated_proxies(page,finder_name)
      @rlp_services.map do |language,service|
        translation = translation(page,language)
        next if translation.nil?
        Concurrent::Future.execute(executor: @pool) do
          service.send("find_#{finder_name}_by_name",remove_scope(translation))
        end
      end.compact.map do |future|
        future.value(@timeout)
      end.flatten.compact
    end

    def translation(category,language_code)
      translation = category.translations.find{|t| t.language == language_code.to_s }
      return nil if translation.nil?
      translation.value
    end

    def remove_scope(name)
      name.sub(/^[^:]+:/,"")
    end

    def finder_name(page)
      page.class.to_s.gsub("::","_").downcase.pluralize
    end
  end
end
