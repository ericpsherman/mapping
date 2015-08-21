require 'bundler/setup'
require 'rod/rest'
require 'cyclopedio/wiki'
require 'cyclopedio/mapping/context_provider'

module Cyclopedio
  module Mapping
    describe ContextProvider do
      let(:provider)    { Mapping::ContextProvider.new(rlp_services: {pl: pl_service}) }
      let(:pl_service)  { Rod::Rest::Client.new(http_client: Faraday.new(url: "http://localhost:2002")) }
      let(:category)  { Cyclopedio::Wiki::Category.find_by_name(name) }

      before(:all) do
        Cyclopedio::Wiki::Database.instance.open_database(ENV['WIKI_DB'])
      end

      after(:all) do
        Cyclopedio::Wiki::Database.instance.close_database
      end

      describe "#parents_for" do
        context "Polish monarchs" do
          let(:name)      { "Polish monarchs" }

          it "provides parent categories from the remote service" do
            provider.parents_for(category).size.should > category.parents.select{|c| c.regular? && c.plural? }.size
          end
        end

        context "Baritones" do
          let(:name)      { "Baritones" }

          it "provides parent categories from eponymous category" do
            provider.parents_for(category).size.should > category.parents.select{|c| c.regular? && c.plural? }.size
          end
        end

        context "Category without translations" do
          let(:name)      { "Minor Prophets" }

          it "should not raise an exception" do
            lambda { provider.parents_for(category) }.should_not raise_error(Exception)
          end
        end
      end

      describe "#children_for" do
        context "Baritones" do
          let(:name)      { "Baritones" }

          it "provides child categories from the remote service" do
            provider.children_for(category).size.should > category.children.select{|c| c.regular? && c.plural? }.size
          end
        end

        context "Category without translations" do
          let(:name)      { "Minor Prophets" }

          it "should not raise an exception" do
            lambda { provider.children_for(category) }.should_not raise_error(Exception)
          end
        end
      end

      describe "#articles_for" do
        context "Baritones" do
          let(:name)      { "Baritones" }

          it "provides articles from the remote service" do
            provider.articles_for(category).size.should > category.concepts.to_a.size
          end
        end

        context "Category without translations" do
          let(:name)      { "Minor Prophets" }

          it "should not raise an exception" do
            lambda { provider.articles_for(category) }.should_not raise_error(Exception)
          end
        end
      end
    end
  end
end

