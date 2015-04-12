require 'bundler/setup'
require 'rr'
require 'cycr'
$:.unshift "lib"
require 'mapping/filter/black_list_filter'
require 'mapping/service/cyc_name_service'
require 'mapping/cyc_term'

module Mapping
  module Filter
    describe BlackListFilter do
      subject               { BlackListFilter.new([:Dog]) }
      let(:cyc)             { Cyc::Client.new(host: ENV['CYC_HOST'] || "localhost") }

      it "should filter elements from the black list" do
        name_service = Service::CycNameService.new(cyc)
        term_dog = name_service.find_by_term_name("Dog")
        term_individual = name_service.find_by_term_name("Individual")
        subject.apply([term_dog,term_individual]).should == [term_individual]
      end
    end
  end
end
