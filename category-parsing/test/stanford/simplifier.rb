$:.unshift "lib"

require 'syntax/stanford/simplifier'
require 'syntax/stanford/converter'

module Syntax
  module Stanford

    describe Simplifier do
      subject             { Simplifier.new(node) }
      let(:node)          { Converter.new(description).object_tree }

      context "with sole head" do
        let(:description)   { "(NNS=H Universities)" }

        it "should simplify only once" do
          subject.simplify do |expression|
            expression.should == "Universities"
          end
        end
      end

      context "with many qualifiers" do
        let(:description)   { "(NP (NNP World) (NNP War) (NNP II) (NN aircraft) (NNS=H carriers))" }

        it "should yield an expression with modifiers removed one by one" do
          words = "World War II aircraft carriers".split(" ")
          subject.simplify.with_index do |expression,index|
            expression.should == words[index..-1].join(" ")
          end
        end
      end

      context "with expression on the right of the head" do
        let(:description)   { "(NP (JJ Fictional) (NN secret) (NNS=H agents) (CC and) (NNS spies))" }

        it "should yield an expression with the right part removed first" do
          results = [
            "Fictional secret agents and spies",
            "Fictional secret agents",
            "secret agents",
            "agents"
          ]
          subject.simplify do |expression|
            expression.should == results.shift
          end
        end
      end
    end
  end
end
