require 'bundler/setup'
require 'rr'
require 'cycr'
require 'cyclopedio/mapping/filter/type_filter'
require 'cyclopedio/mapping/service/type_service'

module Cyclopedio
  module Mapping
    module Filter
      describe TypeFilter do
        subject               { TypeFilter.new(allowed: [:collection],cyc: cyc) }
        let(:cyc)             { Cyc::Client.new(host: ENV['CYC_HOST'] || "localhost") }

        it "should filter terms that are not collections" do
          name_service = Cyc::Service::NameService.new(cyc)
          term_book = name_service.find_by_term_name("Book-CW")
          term_review = name_service.find_by_term_name("bookReview")
          subject.apply([term_book,term_review]).should == [term_book]
        end
      end
    end
  end
end

