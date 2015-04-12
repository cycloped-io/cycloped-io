require 'htmlentities'

module Rlp
  module Wiki
    class Page < Model
      # The id of the page assigned by Wikipedia miner.
      # It is the (1) field in the +page.csv+ file.
      field :wiki_id, :ulong, :index => :hash, :cache_size => 64 * 1024 * 1024

      # The name of the page extracted by Wikipedia miner.
      # It is the (2) field in the +page.csv+ file.
      # For each subclass (concept,category) it uniquely identifies the page.
      field :name, :string, :index => :hash, :cache_size => 128 * 1024 * 1024

      # The depth of the page, that is the distance of the
      # page from the root category.
      # It is the (4) field in the +page.csv+ file.
      field :depth, :integer

      # The offset of the article text in the wikipedia dump file.
      field :text_offset, :ulong

      # The length of the article text in the wikipedia dump file.
      field :text_length, :ulong

      # The translations of the page into other languages.
      # The translations are kept in +translation.csv+ file.
      has_many :translations

      # The redirects of the concept are made of pages redirecting to this page.
      has_many :redirects

      # The templates that are present on the article's Wikipedia page.
      # TODO
      # has_many :templates


      validates_presence_of :wiki_id, :name

      # Returns the contents of the Wikipedia page.
      def contents
        coder = HTMLEntities.new
        self.class.dump_file.pos = self.text_offset
        text = self.class.dump_file.read(self.text_length).force_encoding("utf-8")
        coder.decode(text)
      end

      # Returns short representation of the page.
      def inspect
        "#{self.class.to_s.split("::").last}:#{self.name}"
      end

      class << self
        @@dump_path = nil

        # The path to the full Wikipedia pages dump. This must be set up
        # in order for the Page#contents method to work.
        def path=(path)
          @@dump_path = path
        end

        # Returns the file handle of the wikipedia dump. Raises exception
        # if the +dump_path+ is not set.
        def dump_file
          return @dump_file if defined?(@dump_file)
          raise "Wikipedia path not set" if @@dump_path.nil?
          @dump_file = File.open(@@dump_path,"r:utf-8")
          at_exit do
            @dump_file.close
          end
          @dump_file
        end

        # Finds the article by +name+ following redirects.
        def find_with_redirect(name)
          result = self.find_by_name(name)
          return result unless result.nil?
          redirects = Redirect.find_all_by_name(name)
          (redirect = redirects.select{|r| self === r.page }.first) && redirect.page
        end

        # Finds the article by +wiki_id+ following redirects.
        def find_with_redirect_id(wiki_id)
          result = self.find_by_wiki_id(wiki_id)
          return result unless result.nil?
          redirects = Redirect.find_all_by_wiki_id(wiki_id)
          (redirect = redirects.select{|r| self === r.page }.first) && redirect.page
        end
      end
    end
  end
end
