require 'bundler/setup'
require 'cycr'
require 'cyclopedio/syntax'
require_relative '../test_helper'
require 'cyclopedio/mapping'

module Cyclopedio
  module Mapping
    module Service
      describe TermMerger do
        subject               { TermMerger.new(cyc: cyc) }
        let(:cyc)             { Cyc::Client.new(host: ENV['CYC_HOST'] || "localhost") }

        context "with 'Dog' and 'Cat' terms" do
          let(:term1)     { :Dog }
          let(:term2)     { :Cat }

          it "merges the terms" do
            result = subject.merge(term1,term2)
            result.size.should == 1
            result.first.should == :CarnivoreOrder
          end
        end
      end
    end
  end
end

