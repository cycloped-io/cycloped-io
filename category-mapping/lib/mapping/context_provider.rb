require 'concurrent'

module Mapping

  class Context
    def initialize(entity, context_provider)
      @entity = entity
      @context_provider = context_provider
      @parents = {0 => [entity]}
      @children = {0 => [entity]}
      @articles = {}
      @categories = {}
    end

    # Parents of the category according to wide context.
    def get_parents(distance=nil)
      if distance.nil?
        distance= @context_provider.distance
      end

      distance.times do |dist|
        next if @parents.include?(dist+1)
        @parents[dist+1] = []
        @parents[dist].each do |category|
          from_eponymous = category.eponymous_concepts.map do |concept|
            concept.categories.to_a
          end.flatten
          @parents[dist+1].concat ((@context_provider.remote_counterparts(category, :parents, Rlp::Wiki::Category) + category.parents.to_a + from_eponymous).
                                      select { |c| c.regular? && c.plural? })
        end
      end

      @parents
    end

    # Children of the category according to wide context.
    def get_children(distance=nil)
      if distance.nil?
        distance= @context_provider.distance
      end

      distance.times do |dist|
        next if @children.include?(dist+1)
        @children[dist+1] = []
        @children[dist].each do |category|
          @children[dist+1].concat ((@context_provider.remote_counterparts(category, :children, Rlp::Wiki::Category) + category.children.to_a).
                                       select { |c| c.regular? && c.plural? })
        end
      end

      @children
    end

    # Articles of the category according to wide context.
    def get_articles(distance=nil)
      if distance.nil?
        distance= @context_provider.distance
      end

      distance.times do |dist|
        next if @articles.include?(dist+1)
        @articles[dist+1] = []
        get_children(dist)[dist].each do |category|
          @articles[dist+1].concat ((@context_provider.remote_counterparts(category, :concepts, Rlp::Wiki::Concept) + category.concepts.to_a))
        end
      end

      @articles
    end

    # Categories of the concept according to wide context.
    def get_categories(distance=nil)
      if distance.nil?
        distance= @context_provider.distance
      end

      if @categories.include?(distance)
        return @categories
      end


      distance.times do |dist|
        next if @categories.include?(dist+1)

        if dist+1==1
          from_eponymous = @entity.eponymous_categories.map do |category|
            category.parents.to_a
          end.flatten
          @categories[dist+1] = (@context_provider.remote_counterparts(@entity, :categories, Rlp::Wiki::Category) + @entity.categories.to_a + from_eponymous).
              select { |c| c.regular? && c.plural? }
          next
        end

        @categories[dist+1] = []
        @categories[dist].each do |category|
          from_eponymous = category.eponymous_concepts.map do |concept|
            concept.categories.to_a
          end.flatten
          @categories[dist+1].concat ((@context_provider.remote_counterparts(category, :parents, Rlp::Wiki::Category) + category.parents.to_a + from_eponymous).
                                         select { |c| c.regular? && c.plural? })
        end
      end

      @categories
    end


  end

  class ContextProvider
    MAX_COLLECTION_SIZE = 1000
    # Options:
    # * +rlp_services+ - services used to talk to remote RLP DBs.
    # * +pool_size+ - thread pool size
    def initialize(options={})
      @rlp_services = options.fetch(:rlp_services)
      @distance = options.fetch(:distance)
      pool_size = options.fetch(:pool_size, 3)
      @pool = Concurrent::FixedThreadPool.new(pool_size)
      @timeout = 15
    end

    attr_reader :distance

    # Returns object for accessing context.
    def get_context(entity)
      Context.new(entity, self)
    end

    def remote_counterparts(page, relation, related_class)
      translated_proxies(page, finder_name(page)).map do |proxy|
        Concurrent::Future.execute(executor: @pool) do
          if proxy.send(relation).size > MAX_COLLECTION_SIZE
            elements = proxy.send(relation)[0..MAX_COLLECTION_SIZE]
          else
            elements = proxy.send(relation)
          end
          elements.map do |related_proxy|
            related_proxy.translations.find { |t| t.language == "en" }
          end.compact.map { |t| remove_scope(t.value) }.map { |t| related_class.find_by_name(t) }.compact
        end
      end.map { |f| f.value(@timeout) }.compact.flatten
    end

    private
    def translated_proxies(page, finder_name)
      @rlp_services.map do |language, service|
        translation = translation(page, language)
        next if translation.nil?
        Concurrent::Future.execute(executor: @pool) do
          service.send("find_#{finder_name}_by_name", remove_scope(translation))
        end
      end.compact.map do |future|
        future.value(@timeout)
      end.flatten.compact
    end

    def translation(category, language_code)
      translation = category.translations.find { |t| t.language == language_code.to_s }
      return nil if translation.nil?
      translation.value
    end

    def remove_scope(name)
      name.sub(/^[^:]+:/, "")
    end

    def finder_name(page)
      page.class.to_s.gsub("::", "_").downcase.pluralize
    end
  end
end
