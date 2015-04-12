require 'bundler/setup'
$:.unshift "lib"
require 'mapping/wikipedia_name_converter'

module Mapping
  describe WikipediaNameConverter do
    subject         { WikipediaNameConverter.new(name) }
    let(:name)      { "People" }

    context "conversion to Cyc" do

      it "should convert to Cyc names" do
        subject.to_cyc.should == "People"
      end

      context "with multi-word expression" do
        let(:name)    { "Polish people" }

        it "should camel-case the name" do
          subject.to_cyc.should == "PolishPeople"
        end
      end

      context "with qualified names" do
        let(:name)    { "Washington (state)" }

        it "should put dash between the name and qualifier" do
          subject.to_cyc.should == "Washington-State"
        end
      end

      context "with qualified names and qualifier skipped" do
        let(:name)    { "Washington (state)" }

        it "should put dash between the name and qualifier" do
          subject.to_cyc(skip_qualifier: true).should == "Washington"
        end
      end

      context "with name containing abbreviations and symbols" do
        let(:name)    { "Washington II" }

        it "keeps the abbreviation part capitalized" do
          subject.to_cyc.should == "WashingtonII"
        end
      end
    end
  end
end
