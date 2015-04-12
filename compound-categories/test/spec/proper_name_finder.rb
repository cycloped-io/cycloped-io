$:.unshift "lib"
require 'compound/proper_name_finder'
require_relative '../test_helper'


module Compound
  describe ProperNameFinder do
    let(:finder)            { ProperNameFinder.new(articles_source,extractor) }
    let(:articles_source)   { Object.new }
    let(:extractor)         { Object.new }

    context "name of one of the concepts is covered by the name of the other" do
      let(:name)            { "Petersburg Census Area, Alaska" }
      let(:covering_name)   { "Petersburg Census Area" }
      let(:covered_name)    { "Census Area" }

      before do
        mock(extractor).proper_names(name).stub!.map.yields(covering_name,(0..2)) { [[covering_name,covering_name,(0..2)],
                                                                                     [covered_name,covered_name,(1..2)]] }

        stub(articles_source).find_with_redirect(covering_name) { covering_name }
        stub(articles_source).find_with_redirect(covered_name) { covered_name }
      end

      it "doesn't find concept which name is covered by the other" do
        pages = finder.find(name)
        pages.map(&:first).should include(covering_name)
        pages.map(&:first).should_not include(covered_name)
      end
    end

    context "overlapping names with different length" do
      let(:name)            { "Polish Music in Krakow" }
      let(:shorter_name)     { "Polish Music" }
      let(:longer_name)    { "Music in Krakow" }

      before do
        mock(extractor).proper_names(name).stub!.map.yields(longer_name,(0..2)) { [[shorter_name,(0..1)],[longer_name,(1..3)]] }

        stub(articles_source).find_with_redirect(longer_name)  { longer_name }
        stub(articles_source).find_with_redirect(shorter_name) { shorter_name }
      end

      # Mybe it is not the best idea to exclude one of the results - the purpose
      # is pattern mining, so it is hard to decide which pattern would be more
      # fruitful.
      xit "preferes the longer name" do
        pages = finder.find(name)
        pages.should include(longer_name)
        pages.should_not include(shorter_name)
      end
    end
  end
end
