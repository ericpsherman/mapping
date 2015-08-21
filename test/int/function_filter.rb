require 'bundler/setup'
require 'rr'
require 'cycr'
require 'cyclopedio/mapping/filter/function_filter'

module Cyclopedio
  module Mapping
    module Filter
      describe FunctionFilter do
        subject               { FunctionFilter.new }
        let(:cyc)             { Cyc::Client.new(host: ENV['CYC_HOST'] || "localhost") }

        it "should filter generalizations of other terms" do
          name_service = Cyc::Service::NameService.new(cyc)
          term_mother = name_service.find_by_term_name("MotherFn")
          term_individual = name_service.find_by_term_name("Individual")
          subject.apply([term_mother,term_individual]).should == [term_individual]
        end
      end
    end
  end
end

