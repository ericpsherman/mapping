require 'bundler/setup'
require 'rr'
require 'cycr'
require 'cyclopedio/mapping/filter/most_specific_filter'

module Cyclopedio
  module Mapping
    module Filter
      describe MostSpecificFilter do
        subject               { MostSpecificFilter.new(cyc: cyc) }
        let(:cyc)             { Cyc::Client.new(host: ENV['CYC_HOST'] || "localhost") }

        it "should filter generalizations of other terms" do
          name_service = Cyc::Service::NameService.new(cyc)
          term_dog = name_service.find_by_term_name("Dog")
          term_individual = name_service.find_by_term_name("Individual")
          subject.apply([term_dog,term_individual]).should == [term_dog]
        end
      end
    end
  end
end

