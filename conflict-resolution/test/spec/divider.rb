require 'bundler/setup'
require 'rr'
$:.unshift "lib"
require 'resolver/divider'

module Resolver
  describe Divider do
    def set_disjoint(c1,c2,value,service)
      stub(service).call(c1,c2) { value }
      stub(service).call(c2,c1) { value }
    end

    def create_node(value)
      stub!.value { value }.subject
    end

    let(:divider)     { Divider.new(&service) }
    let(:graph)       { stub!.leafs { leafs }.subject }
    let(:service)     { ->(a,b) { } }

    context "two disjoint collections" do
      let(:dog)       { "dog" }
      let(:cat)       { "cat" }
      let(:leafs)     { [create_node(dog),create_node(cat)] }

      before do
        set_disjoint(dog,cat,true,service)
      end

      it "provides two 1-element partitions" do
        partitions = divider.partitions(graph)
        partitions.size.should == 2
        partitions[0].size.should == 1
        partitions[1].size.should == 1
      end
    end

    context "three collections, where two are disjoint" do
      let(:man)       { "man" }
      let(:woman)     { "woman" }
      let(:writer)    { "writer" }
      let(:leafs)     { [create_node(man),create_node(woman),create_node(writer)] }

      before do
        set_disjoint(man,woman,true,service)
        set_disjoint(man,writer,false,service)
        set_disjoint(woman,writer,false,service)
      end

      it "provides two 2-element partitions" do
        partitions = divider.partitions(graph)
        partitions.size.should == 2
        partitions[0].size.should == 2
        partitions[0].map(&:value).should include(writer)
        partitions[1].size.should == 2
        partitions[1].map(&:value).should include(writer)
      end
    end

    context "four collections, where two are disjoint" do
      let(:man)       { "man" }
      let(:woman)     { "woman" }
      let(:writer)    { "writer" }
      let(:director)   { "director" }
      let(:leafs)     { [create_node(man),create_node(woman),create_node(writer),create_node(director)] }

      before do
        set_disjoint(man,woman,true,service)
        set_disjoint(man,writer,false,service)
        set_disjoint(woman,writer,false,service)
        set_disjoint(man,director,false,service)
        set_disjoint(woman,director,false,service)
        set_disjoint(writer,director,false,service)
      end

      it "provides two 3-element partitions" do
        partitions = divider.partitions(graph)
        partitions.size.should == 2
        partitions[0].size.should == 3
        partitions[0].map(&:value).should include(writer)
        partitions[0].map(&:value).should include(director)
        partitions[1].size.should == 3
        partitions[1].map(&:value).should include(writer)
        partitions[1].map(&:value).should include(director)
      end
    end
  end
end
