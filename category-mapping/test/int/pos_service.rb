require 'bundler/setup'
require 'cycr'
$:.unshift "lib"
require 'mapping/cyc_term'
require 'mapping/service/cyc_name_service'
require 'mapping/service/pos_service'

module Mapping
  module Service
    describe PosService do
      subject       { PosService.new(cyc) }
      let(:cyc)             { Cyc::Client.new(host: ENV['CYC_HOST'] || "localhost") }

      it "should return :noun for Dog" do
        subject.part_of_speech(:Dog).should == :noun
      end

      it "should return :verb for Booking-MakingAReservation" do
        subject.part_of_speech(:"Booking-MakingAReservation").should == :verb
      end

      it "should return :adjective for slow" do
        subject.part_of_speech([:LowAmountFn, :Speed]).should == :adjective
      end

      it "should return nil for EnglishMt" do
        subject.part_of_speech(:EnglishMt).should == nil
      end
    end
  end
end
