require 'bundler/setup'
$:.unshift "lib"
require 'compound/pattern_builder'

module Compound
  describe PatternBuilder do
    context "1999 expatriates from Poland to Nigeria" do
      let(:builder)     { PatternBuilder.new }
      let(:name)        { "1999 expatriates from Poland to Nigeria" }
      let(:matches)     { [year,poland,nigeria] }
      let(:year)        { ["","1999"," expatriates from Poland to Nigeria"] }
      let(:poland)      { ["1999 expatriates from ","Poland"," to Nigeria"] }
      let(:nigeria)     { ["1999 expatriates from Poland to ","Nigeria",""] }

      it "yields 1-order patterns" do
        patterns = builder.build(name,matches).select{|p,o| o == 1 }.map(&:first)
        patterns.should include("N expatriates from Poland to Nigeria")
        patterns.should include("1999 expatriates from X to Nigeria")
        patterns.should include("1999 expatriates from Poland to X")
      end

      it "yields 2-order patterns" do
        patterns = builder.build(name,matches).select{|p,o| o == 2 }.map(&:first)
        patterns.should include("N expatriates from X to Nigeria")
        patterns.should include("N expatriates from Poland to X")
        patterns.should include("1999 expatriates from X to Y")
      end

      it "yields 3-order patterns" do
        patterns = builder.build(name,matches).select{|p,o| o == 3 }.map(&:first)
        patterns.should include("N expatriates from X to Y")
      end
    end
  end
end
