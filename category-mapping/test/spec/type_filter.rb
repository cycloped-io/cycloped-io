require 'bundler/setup'
require 'rr'
$:.unshift "lib"
require 'mapping/filter/type_filter'
require_relative '../test_helper'


module Mapping
  module Filter
    describe TypeFilter do
      subject               { TypeFilter.new(allowed: allowed, type_service: type_service, cyc: cyc) }
      let(:terms)           { [term_collection,term_individual,term_relation] }
      let(:term_collection) { stub!.subject }
      let(:term_individual) { stub!.subject }
      let(:term_relation)   { stub!.subject }
      let(:cyc)             { stub!.subject }

      let(:type_service)  { service = stub!.term_type(term_collection){ :collection }.subject
                            stub(service).term_type(term_individual) { :individual }
                            stub(service).term_type(term_relation) { :relation }
                            service
      }

      context "with all types allowed" do
        let(:allowed)   { :all }

        it "should not filter any terms" do
          subject.apply(terms).should == terms
        end
      end

      context "with collections allowed" do
        let(:allowed)   { [:collection] }

        it "should pass only collection terms" do
          subject.apply(terms).should == [term_collection]
        end
      end

      context "with collections and relations allowed" do
        let(:allowed)   { [:collection, :relation] }

        it "should pass only collection and relation terms" do
          filtered = subject.apply(terms)
          filtered.should include(term_collection)
          filtered.should include(term_relation)
          filtered.size.should == 2
        end
      end
    end
  end
end
