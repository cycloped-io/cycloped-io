require 'bundler/setup'
require 'rr'
require 'cycr'
$:.unshift "lib"
require 'mapping/filter/pos_filter'
require 'mapping/service/pos_service'
require 'mapping/service/cyc_name_service'
require 'mapping/cyc_term'

module Mapping
  module Filter
    describe PosFilter do
      subject               { PosFilter.new(cyc: cyc,allowed: [:noun]) }
      let(:cyc)             { Cyc::Client.new(host: ENV['CYC_HOST'] || "localhost") }

      it "should filter terms that do not correspond to nouns" do
        name_service = Service::CycNameService.new(cyc)
        term_book = name_service.find_by_term_name("Book-CW")
        term_booking = name_service.find_by_term_name("Booking-MakingAReservation")
        subject.apply([term_book,term_booking]).should == [term_book]
      end
    end
  end
end
