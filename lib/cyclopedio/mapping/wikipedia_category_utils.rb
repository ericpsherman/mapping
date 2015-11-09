require 'cyclopedio/syntax'
require 'wiktionary/noun'

module Cyclopedio
  module Mapping
    # This class provides methods for processing category names and its parsed trees.
    class WikipediaCategoryUtils
      def initialize(options={})
        @parse_tree_factory = options[:parse_tree_factory] || Cyclopedio::Syntax::Stanford::Converter
        @nouns = options[:nouns] || Wiktionary::Noun.new
      end


      # Returns the first parse tree of the +category+ name.
      def category_head_tree(category)
        convert_head_into_object(category.parsed_head)
      end

      # Returns the word (string) being a head of the +category+ name.
      def category_head(category)
        head_node = category_head_tree(category).find_head_noun
        head_node && head_node.content
      end

      # Returns a list of parse trees of the +category+ name.
      # The might be more parse trees for categories such as "Cities and
      # villages in X", etc.
      def category_head_trees(category)
        if category.multiple_heads?
          category.parsed_heads.map{|h| convert_head_into_object(h) }
        else
          [category_head_tree(category)]
        end
      end

      # Converts the string representing the parsed +head+ into tree of objects.
      def convert_head_into_object(head)
        @parse_tree_factory.new(head).object_tree
      end

      # Singularize using Wiktionary data. The result is an array of Strings.
      def singularize_name(name, head)
        names = []
        singularized_heads = @nouns.singularize(head)
        if singularized_heads
          singularized_heads.each do |singularized_head|
            names << name.sub(/\b#{Regexp.quote(head)}\b/, singularized_head)
          end
        end
        names << name if names.empty?
        names
      end

      def remove_parentheses(name)
        return name if name !~ /\(/ || name =~ /^\(/
        name.sub(/\([^)]*\)/,"").strip
      end

      def type_in_parentheses(name)
        type = name[/\([^)]*\)/]
        type ? type[1..-2] : ""
      end

    end
  end
end

