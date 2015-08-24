require 'concurrent'
require 'cyclopedio/wiki'

module Cyclopedio
  module Mapping
    class ContextProvider
      MAX_COLLECTION_SIZE = 1000
      # Options:
      # * +remote_services+ - services used to talk to remote Wiki DBs.
      # * +pool_size+ - thread pool size
      # * +language+ - the language of the source page
      # * +distance+ - the distance of the context
      def initialize(options={})
        @remote_services = options.fetch(:remote_services)
        pool_size = options.fetch(:pool_size,3)
        @pool = Concurrent::FixedThreadPool.new(pool_size)
        @context_factory = options[:context_factory] || Context
        @timeout = 15
        @language = options[:language] || "en"
        @distance = options[:distance] || 1
      end

      # Returns the context object of the +entity+ used to fetch its relatives.
      def context(entity)
        @context_factory.new(entity,@distance,self)
      end

      # Returns remote relatives (of class +related_class+ and of +relationship+ type) of the +page+.
      def relatives(page,relationship,related_class)
        translated_proxies(page,finder_name(page)).map do |proxy|
          Concurrent::Future.execute(executor: @pool) do
            if proxy.public_send(relationship).size > MAX_COLLECTION_SIZE
              elements = proxy.public_send(relationship)[0..MAX_COLLECTION_SIZE]
            else
              elements = proxy.public_send(relationship)
            end
            elements.map do |related_proxy|
              related_proxy.translations.find{|t| t.language == @language }
            end.compact.map{|t| remove_scope(t.value) }.map{|t| related_class.find_by_name(t) }.compact
          end
        end.map{|f| f.value(@timeout) }.compact.flatten
      end

      private
      def translated_proxies(page,finder_name)
        @rlp_services.map do |language,service|
          translation = translation(page,language)
          next if translation.nil?
          Concurrent::Future.execute(executor: @pool) do
            service.public_send("find_#{finder_name}_by_name",remove_scope(translation))
          end
        end.compact.map do |future|
          future.value(@timeout)
        end.flatten.compact
      end

      def translation(category,language_code)
        translation = category.translations.find{|t| t.language == language_code.to_s }
        return nil if translation.nil?
        translation.value
      end

      def remove_scope(name)
        name.sub(/^[^:]+:/,"")
      end

      def finder_name(page)
        page.class.to_s.gsub("::","_").downcase.pluralize
      end
    end
  end
end
