require 'bundler/setup'
require 'cycr'
$:.unshift "lib"
require 'mapping/service/type_service'

module Mapping
  module Service
    describe TypeService do
      subject               { TypeService.new(cyc) }
      let(:cyc)             { Cyc::Client.new(host: ENV['CYC_HOST'] || "localhost") }

      it "should return :microtheory for UniversalVocabularyMt" do
        subject.term_type(:UniversalVocabularyMt).should == :microtheory
      end

      it "should return :relation for isa" do
        subject.term_type(:isa).should == :relation
      end

      it "should return :individual for MichaelJackson" do
        subject.term_type(:MichaelJackson).should == :individual
      end

      it "should return :collection for Dog" do
        subject.term_type(:Dog).should == :collection
      end
    end
  end
end
