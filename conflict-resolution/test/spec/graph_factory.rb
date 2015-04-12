require 'bundler/setup'
require 'rr'
$:.unshift "lib"
require 'resolver/graph_factory'

module Resolver
  describe GraphFactory do
    let(:factory)     { GraphFactory.new(&service) }
    let(:service)     { ->(a,b) { }  }

    context "two roots" do
      let(:person)          { "person" }
      let(:organization)    { "organization" }

      before do
        stub(service).call(person,organization) { 0 }
        stub(service).call(organization,person) { 0 }
      end

      it "returns both roots" do
        roots = factory.create([person,organization]).roots.map{|e| e.value }
        roots.size.should == 2
        roots.should include(person)
        roots.should include(organization)
      end
    end

    context "one root" do
      let(:animal)          { "animal" }
      let(:human)           { "human" }

      before do
        stub(service).call(animal,human) { 1 }
        stub(service).call(human,animal) { -1 }
      end

      it "returns root with a child" do
        roots = factory.create([human,animal]).roots
        roots.size.should == 1
        roots.first.value.should == animal
        roots.first.children.first.value.should == human
      end

      context "two-level hierarchy" do
        let(:policeman)     { "policeman" }

        before do
          stub(service).call(policeman,animal) { -1 }
          stub(service).call(animal,policeman) { 1 }
          stub(service).call(policeman,human) { -1 }
          stub(service).call(human,policeman) { 1 }
        end

        it "returns linear hierarchy" do
          roots = factory.create([human,animal,policeman]).roots
          roots.size.should == 1
          animal_node = roots.first
          animal_node.value.should == animal
          animal_node.children.size.should == 1
          human_node = animal_node.children.first
          human_node.value.should == human
          human_node.children.size.should == 1
          human_node.parents.size.should == 1
          human_node.parents.first.should == animal_node
          policeman_node = human_node.children.first
          policeman_node.value.should == policeman
          policeman_node.parents.size.should == 1
          policeman_node.parents.first.should == human_node
        end
      end
    end
  end
end
