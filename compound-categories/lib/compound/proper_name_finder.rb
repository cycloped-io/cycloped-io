module Compound
  class ProperNameFinder
    # Creates new proper name finder. It uses +pages_source+ to find existing
    # pages and +proper_name_extractor+ to split the names of Wikipedia
    # pages.
    def initialize(pages_source,proper_name_extractor)
      @pages = pages_source
      @extractor = proper_name_extractor
    end

    # Finds pages whose names are present in the passed name.
    def find(page_name)
      all_pages = @extractor.proper_names(page_name).map do |name,range|
        page = @pages.find_with_redirect(name)
        page = @pages.find_by_label(name) unless page
        if page
          [page,name,range]
        end
      end.compact
      all_pages.inject([]) do |result,(page,name,range)|
        if all_pages.any?{|p,n,r| p != page && covers?(r,range) }
          result
        else
          result << [page,name,range]
        end
      end.compact
    end

    private
    def covers?(range1,range2)
      range1.first <= range2.first && range1.last >= range2.last
    end

    def overlap?(range1,range2)
      range1.first <= range2.last && range2.first <= range1.last
    end
  end
end
