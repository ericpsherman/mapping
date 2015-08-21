require 'bundler/setup'
require 'cycr'
$:.unshift "lib"
require 'cyclopedio/mapping/service/pos_service'

module Cyclopedio
  module Mapping
    module Service
      describe PosService do
        subject             { PosService.new(name_service) }
        let(:cyc)           { Cyc::Client.new(host: ENV['CYC_HOST'] || "localhost") }
        let(:name_service)  { Cyc::Service::NameService.new(cyc) }

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
end

