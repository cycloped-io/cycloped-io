$:.unshift "lib"

require 'syntax/stanford/converter'

module Syntax
  module Stanford

    describe Converter do
      subject             { Converter.new(description) }
      let(:description)   { "()" }

      it "should parse empty tree" do
        subject.array_tree.should == []
        subject.object_tree.to_s.should == description
      end

      context "with single node" do
        let(:description) { "(NNP=H)" }

        it "should parse the tree" do
          subject.array_tree.should == ["NNP=H"]
          subject.object_tree.to_s.should == description
        end
      end


      context "with subtree" do
        let(:description) { "(NP (NPN=John NPN=Smith))" }

        it "should parse tree with a subtree" do
          subject.array_tree.should == ["NP", ["NPN=John", "NPN=Smith"]]
          subject.object_tree.to_s.should == description
        end
      end
    end
  end
end
