# encoding: utf-8

module Cyclopedio
  module Mapping
    # Class used to convert Wikipedia names to different mapping schemas.
    class WikipediaNameConverter
      def initialize(name)
        @name = name
      end

      # Converts the Wikipedia category name to Cyc-like name.
      def to_cyc(options={})
        head, qualifier = @name.split("(")
        head = capitalize_and_squeeze_words(head)
        if qualifier && !options[:skip_qualifier]
          "#{head}-" + capitalize_and_squeeze_words(qualifier.sub(")",""))
        else
          head
        end
      end

      private
      def capitalize_and_squeeze_words(words)
        words.gsub("-"," ").split(" ").map do |segment|
          if segment =~ /\p{Lu}/
            segment
          else
            segment.capitalize
          end
        end.join("")
      end
    end
  end
end

