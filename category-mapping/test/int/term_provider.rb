require 'bundler/setup'
require 'cycr'
require 'syntax/stanford/node'
require 'syntax/stanford/simplifier'
require 'syntax/stanford/converter'
require_relative '../test_helper'
$:.unshift "lib"
require 'mapping'

module Mapping
  describe TermProvider do
    subject             { TermProvider.new(cyc: cyc, name_service: name_service, name_mapper: name_mapper) }
    let(:name_service)  { Service::CycNameService.new(cyc) }
    let(:category)      { stub(category=Object.new).head_trees { head_trees }
                          stub(category).head { head }
                          stub(category).name { name }
                          category
    }
    let(:head_trees)     { parsed_heads.map{|h| Syntax::Stanford::Converter.new(h).object_tree} }
    let(:cyc)            { Cyc::Client.new(host: ENV['CYC_HOST'] || "localhost") }

    context "only with first name mapping method" do
      let(:name_mapper)   { NameMapper.new(cyc: cyc, name_service: name_service, return_all: false) }

      context "with 'secret agents' category" do
        let(:name)          { "Fictional secret agents and spies"}
        let(:parsed_heads)  { ["(NP (JJ Fictional) (NN secret) (NNS=H agents) (CC and) (NNS spies))"] }
        let(:head)          { "agents" }


        it "should provide IntelligenceOperative candidate" do
          result = subject.category_candidates(category)
          result.size.should == 1
          result.name.should == "secret agents"
          result.candidates.size.should == 1
          result.candidates.first.to_ruby.should == :IntelligenceOperative
        end
      end

      context "with 'books' category" do
        let(:name)          { "Books" }
        let(:parsed_heads)  { ["(NP (NNS=H Books))"] }
        let(:head)          { "Books" }


        it "should only provide 'Book-CW' and 'BookCopy' candidates" do
          result = subject.category_candidates(category)
          result.size.should == 1
          result.name.should == "Books"
          result.candidates.size.should == 7
          result.candidates.map(&:to_ruby).should include(:"Book-CW")
          result.candidates.map(&:to_ruby).should include(:"BookCopy")
        end
      end

      context "with 'Canadian football trophies and awards' category" do
        let(:name)          { "Canadian football trophies and awards" }
        let(:parsed_heads)  { ["(NP (JJ Canadian) (NN football) (NNS=H trophies))", "(NP (NNS awards))"] }
        let(:head)          { "throphies" }

        it "should provide candidates for both heads" do
          result = subject.category_candidates(category)
          result.size.should == 2
          result.name(0).should == "trophies"
          result.candidates(0).map(&:to_ruby).should include(:Trophy)
          result.name(1).should == "awards"
          result.candidates(1).map(&:to_ruby).should include(:GivingAnAward)
        end
      end

      context "with 'John Paul II' article" do
        let(:article)       { stub!.name { name }.subject }
        let(:name)          { "John Paul II" }

        it "should provie 'PopeJohnPaulII' candidates" do
          result = subject.article_candidates(article)
          result.size.should == 1
          result.name.should == "John Paul II"
          result.candidates.map(&:to_ruby).should include(:"PopeJohnPaulII")
        end
      end

      context "with 'Poland (country)' article" do
        let(:article)       { stub!.name { name }.subject }
        let(:name)          { "Poland (country)" }

        it "discards the qualifier" do
          result = subject.article_candidates(article)
          result.size.should == 1
          result.candidates.map(&:to_ruby).should include(:"Poland")
        end
      end
      context "with 'singles' category" do
        let(:name)          { "Singles" }
        let(:parsed_heads)  { ["(NP (NNS=H Singles))"] }
        let(:head)          { "Singles" }


        it "should only provide 'Single' candidate" do
          result = subject.category_candidates(category)
          result.size.should == 1
          result.name.should == "Singles"
          result.candidates.size.should == 1
          result.candidates.map(&:to_ruby).should include(:"Single")
        end
      end
    end

    context "with all name mapping methods" do
      let(:name_mapper)   { NameMapper.new(cyc: cyc, name_service: name_service, return_all: true) }

      context "with 'singles' category" do
        let(:name)          { "Singles" }
        let(:parsed_heads)  { ["(NP (NNS=H Singles))"] }
        let(:head)          { "Singles" }


        it "should provide 'Single' and '?' candidates" do
          result = subject.category_candidates(category)
          result.size.should == 1
          result.name.should == "Singles"
          result.candidates.size.should == 6
          result.candidates.map(&:to_ruby).should include(:"Single")
          result.candidates.map(&:to_ruby).should include(:"SingleRecording-CW")
        end
      end
    end
  end
end
