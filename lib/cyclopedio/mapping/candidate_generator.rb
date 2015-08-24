require 'ref'
require 'cycr'
require 'cyclopedio/syntax'
require 'wiktionary/noun'
require_relative 'name_mapper'
require_relative 'candidate_set'

module Cyclopedio
  module Mapping
    # This class is used to generate candidate Cyc terms for a given Wikipedia
    # category or article. It uses sophisticated name resolution strategy as
    # well as filtering of candidates that are not likely to be mapped to a given
    # category or article.
    class CandidateGenerator
      def initialize(options={})
        @name_service = options[:name_service]
        @cyc = options[:cyc] || Cyc::Client.new(cache: true)
        @name_mapper = options[:name_mapper] || NameMapper.new(cyc: @cyc, name_service: @name_service)
        @simplifier_factory = options[:simplifier_factory] || Cyclopedio::Syntax::Stanford::Simplifier
        @parse_tree_factory = options[:parse_tree_factory] || Cyclopedio::Syntax::Stanford::Converter
        @candidate_set_factory = options[:candidate_set_factory] || CandidateSet

        @category_filters = options[:category_filters] || []
        @article_filters = options[:article_filters] || []
        @genus_filters = options[:genus_filters] || []

        @nouns = options[:nouns] || Wiktionary::Noun.new
        @all_subtrees = options.fetch(:all_subtrees,false)
        @category_exact_match = options.fetch(:category_exact_match,false)

        @category_cache = Ref::WeakValueMap.new
        @article_cache = Ref::WeakValueMap.new
        @concept_types_cache = Ref::WeakValueMap.new
        @term_cache = Ref::WeakValueMap.new
      end

      # Returns the candidate terms for the Wikipedia +category+.
      # The results is a CandidateSet.
      def category_candidates(category)
        return @category_cache[category] unless @category_cache[category].nil?
        # from whole name singularized
        candidates = []
        singularize_name(category.name, category_head(category).each do |name_singularized|
          candidates.concat(candidates_for_name(name_singularized,@category_filters))
        end
        candidate_set = create_candidate_set(category.name,candidates)
        return @category_cache[category] = candidate_set if !candidate_set.empty? || @category_exact_match
        # from simplified name
        candidate_set = candidate_set_for_syntax_trees(category_head_trees(category),@category_filters)
        return @category_cache[category] = candidate_set unless candidate_set.empty?
        # from original whole name
        candidates_set = candidates_set_for_name(category.name, @category_filters)
        @category_cache[category] = candidate_set
      end

      # Return the candidate terms for a given +pattern+ which is exemplified
      # by the +representative+. The result is a CandidateSet.
      def pattern_candidates(pattern,representative)
        candidate_set_for_syntax_trees(representative_head_trees(representative),@category_filters,pattern)
      end

      # Returns the candidate terms for the Wikipedia +article+.
      # The result is a CandidateSet.
      def article_candidates(article)
        return @article_cache[article] unless @article_cache[article].nil?
        candidate_set = candidate_set_for_name(article.name, @article_filters)
        if candidate_set.empty?
          candidate_set = candidate_set_for_name(remove_parentheses(article.name), @article_filters)
        end
        @article_cache[article] = candidate_set
      end

      # Returns the candidates terms for the Wikipedia article genus proxima.
      # The result is a CandidateSet.
      def genus_proximum_candidates(concept)
        return @concept_types_cache[concept] unless @concept_types_cache[concept].nil?
        @concept_types_cache[concept] = candidate_set_for_syntax_trees(concept.types_trees, @genus_filters)
      end

      # Returns the candidates terms for the Wikipedia article type indicated in
      # parentheses.
      # The result is a CandidateSet.
      def parentheses_candidates(concept)
        # TODO cache result for a given type
        type = type_in_parentheses(concept.name)
        candidate_set = create_candidate_set(type,[])
        if !type.empty?
          candidate_set = candidate_set_for_name(type, @genus_filters)
        end
        candidate_set
      end

      # Returns the term that exactly matches provided +cyc_id+. Returned as an
      # array.
      def term_candidates(cyc_id)
        return @term_cache[cyc_id] unless @term_cache[cyc_id].nil?
        @term_cache[cyc_id] = create_candidate_set("",[@name_service.find_by_id(cyc_id)])
      end

      private
      # XXX most of these methods should be moved to external class(es).

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

      # Return candidate set for an entity +name+, with a given +head+ and apply
      # provided +filters+.
      def candidate_set_for_name(name,filters)
        candidates = candidates_for_name(name,filters)
        create_candidate_set(name,candidates)
      end

      # Return the candidates set for the given syntax +trees+. The results are filtered
      # using the +filters+. If +pattern+ is given, it is used to filter out too
    # simplified names based on the +trees+.
      def candidate_set_for_syntax_trees(trees,filters,pattern=nil)
        candidate_set = @candidate_set_factory.new
        trees.each do |tree|
          names = @simplifier_factory.new(tree).simplify.to_a
          if pattern
            names.select! do |name|
              # Pattern won't match too specific name, e.g.
              # "X almumni" does not match /University alumni/
              pattern =~ /#{name}/
            end
          end
          head_node = tree.find_head_noun
          next unless head_node
          head = head_node.content
          names.each do |name|
            simplified_names = singularize_name(name, head)
            candidates = []
            simplified_names.each do |simplified_name|
              candidates.concat(candidates_for_name(simplified_name, filters))
            end
            unless candidates.empty?
              candidate_set.add(name,candidates)
              break unless @all_subtrees
            end
          end
        end
        candidate_set
      end

      # Return candidates for the given +name+ and apply the +filters+ to the
      # result.
      def candidates_for_name(name, filters)
        candidates = @name_mapper.find_terms(name)
        filters.inject(candidates) do |terms, filter|
          filter.apply(terms)
        end
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

      # Create a candidate set for single group of candidates.
      def create_candidate_set(name,candidates)
        result = @candidate_set_factory.new
        result.add(name,candidates) unless candidates.empty?
        result
      end
    end
  end
end

