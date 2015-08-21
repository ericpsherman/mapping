require 'bundler/setup'
require 'rr'
require 'cycr'
require 'cyclopedio/mapping/filter/lower_case_filter'

module Cyclopedio
  module Mapping
    module Filter
      describe LowerCaseFilter do
        subject               { LowerCaseFilter.new }
        let(:cyc)             { Cyc::Client.new(host: ENV['CYC_HOST'] || "localhost") }

        it "should filter generalizations of other terms" do
          name_service = Cyc::Service::NameService.new(cyc)
          term_son = name_service.find_by_term_name("sonInLaw")
          term_individual = name_service.find_by_term_name("Individual")
          subject.apply([term_son,term_individual]).should == [term_individual]
        end
      end
    end
  end
end

