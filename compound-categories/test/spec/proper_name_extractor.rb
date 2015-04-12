require 'bundler/setup'
$:.unshift "lib"
require 'compound/proper_name_extractor'
require_relative '../test_helper'


module Compound
  describe ProperNameExtractor do
    let(:extractor)   { ProperNameExtractor.new }

    context "Events in France" do
      let(:name)        { "Events in France" }

      it "should provide range occupied by the word" do
        extractor.proper_names(name).first.last.should == (0..0)
      end

      it "should extract 'Events' and 'France'" do
        names = extractor.proper_names(name).to_a.map(&:first)
        names.should include("Events")
        names.should include("France")
      end
    end

    context "Petersburg Census Area, Alaska" do
      let(:name)        { "Petersburg Census Area, Alaska" }

      it "should extract 'Events' and 'France'" do
        names = extractor.proper_names(name).to_a.map(&:first)
        names.should include("Petersburg Census Area")
        names.should include("Alaska")
      end
    end

    context "Countries" do
      let(:name)        { "Countries" }

      it "should extract 'Countries'" do
        names = extractor.proper_names(name).to_a.map(&:first)
        names.should include("Countries")
      end
    end

    context "Add N to (X) albums" do
      let(:name)        { "Add N to (X) albums" }

      it "should extract 'Add N to (X)'" do
        names = extractor.proper_names(name).to_a.map(&:first)
        names.should include("Add N to (X)")
        names.should include("Add N to (X")
        names.should include("Add N to (")
        names.should include("Add N to")
      end
    end
  end
end
