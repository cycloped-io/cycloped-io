require 'bundler/setup'
require 'cycr'
$:.unshift "lib"
require 'mapping/cyc_term'
require 'mapping/service/cyc_name_service'

module Mapping
  module Service
    describe CycNameService do
      subject { CycNameService.new(cyc) }
      let(:cyc)             { Cyc::Client.new(host: ENV['CYC_HOST'] || "localhost") }

      context "finding terms by exact name" do
        it "should return nil if the name is not present" do
          subject.find_by_term_name("TherIsNoSuchCycTermName").should == nil
        end

        it "should return CycTerm if the name is present" do
          subject.find_by_term_name("Dog").should be_a_kind_of(CycTerm)
        end
      end

      context "finding terms by id" do
        it "should return nil if the id is invalid" do
          subject.find_by_id("ThereIsNoSuchId").should == nil
        end

        it "should return nil if the id is invalid (deleted)" do
          subject.find_by_id("Mx4rx7lVqDe7QdeKFu5CgJy0xQ").should == nil
        end

        it "should return CycTerm if the id is valid" do
          # Dog ID
          subject.find_by_id("Mx4rvVjaoJwpEbGdrcN5Y29ycA").should be_a_kind_of(CycTerm)
        end
      end

      context "finding terms by prefered label" do
        it "should return nil if the label is not present in Cyc" do
          subject.find_by_label("noSuchLabel").should == nil
        end

        it "should return CycTerm if the label is valid" do
          subject.find_by_label("dog").should be_a_kind_of(CycTerm)
        end

        it "should raise AmbiguousResult exception if the label is ambiguous" do
          (-> { subject.find_by_label("acrylic fiber") }).should raise_exception(AmbiguousResult)
        end

        it "should return ambiguous results inside the exception" do
          begin
            subject.find_by_label("acrylic fiber")
          rescue AmbiguousResult => ex
            ex.results.size.should > 1
            ex.results.each { |r| r.should be_a_kind_of(CycTerm) }
          end
        end
      end

      context "find term by it (ambiguous) name" do
        it "should return empty array if there is no term with given name" do
          subject.find_by_name("NoSuchName").should == []
        end

        it "should return non-empty array if there are terms with given name" do
          subject.find_by_name("dog").size.should > 0
        end

        it "should return CycTerms" do
          subject.find_by_name("dog").each { |t| t.should be_a_kind_of(CycTerm) }
        end
      end

      context "term labels" do
        it "returns labels for a term" do
          labels = subject.labels(subject.find_by_term_name("Dog"))
          labels.include?("dogs").should == true
          labels.include?("hound").should == true
        end

        it "returns canonical label for a term" do
          subject.canonical_label(subject.find_by_term_name("Dog")).should == "dog"
        end
      end
    end
  end
end
