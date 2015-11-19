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
        @infobox_cache = Ref::WeakValueMap.new
      end

      # Returns the candidate terms for the Wikipedia +category+.
      # The results is a CandidateSet.
      def category_candidates(category)
        return @category_cache[category] unless @category_cache[category].nil?
        # from whole name singularized
        candidates = []
        decorated_category = Cyclopedio::Syntax::NameDecorator.new(category, parse_tree_factory: @parse_tree_factory)
        @nouns.singularize_name(category.name, decorated_category.category_head).each do |name_singularized|
          candidates.concat(candidates_for_name(name_singularized,@category_filters))
        end
        candidate_set = create_candidate_set(category.name,candidates)
        return @category_cache[category] = candidate_set if !candidate_set.empty? || @category_exact_match
        # from simplified name
        candidate_set = candidate_set_for_syntax_trees(decorated_category.category_head_trees,@category_filters)
        return @category_cache[category] = candidate_set unless candidate_set.empty?
        # from original whole name
        candidate_set = candidate_set_for_name(category.name, @category_filters)
        @category_cache[category] = candidate_set
      end

      # Return the candidate terms for a given +pattern+ which is exemplified
      # by the +representative+. The result is a CandidateSet.
      def pattern_candidates(pattern,representative)
        candidate_set_for_syntax_trees(representative_head_trees(representative),@category_filters,pattern) #TODO representative_head_trees?
      end

      # Returns the candidate terms for the Wikipedia +article+.
      # The result is a CandidateSet.
      def article_candidates(article)
        return @article_cache[article] unless @article_cache[article].nil?
        candidate_set = candidate_set_for_name(article.name, @article_filters)
        if candidate_set.empty?
          candidate_set = candidate_set_for_name(Cyclopedio::Syntax::NameDecorator.new(article, parse_tree_factory: @parse_tree_factory).remove_parentheses, @article_filters)
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
        type = Cyclopedio::Syntax::NameDecorator.new(concept, parse_tree_factory: @parse_tree_factory).type_in_parentheses
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

      # Returns a candidate set for the given +infobox+. The English name of the
      # infobox is searched for in Cyc. Category filters are applied to the
      # returned candidate set.
      def infobox_candidates(infobox)
        return @infobox_cache[infobox] unless @infobox_cache[infobox].nil?
        @infobox_cache[infobox] = candidate_set_for_name(infobox,@category_filters)
      end

      private
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
              # "X alumni" does not match /University alumni/
              pattern =~ /#{name}/
            end
          end
          head_node = tree.find_head_noun
          next unless head_node
          head = head_node.content
          names.each do |name|
            simplified_names = @nouns.singularize_name(name, head)
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

      # Create a candidate set for single group of candidates.
      def create_candidate_set(name,candidates)
        result = @candidate_set_factory.new
        result.add(name,candidates) unless candidates.empty?
        result
      end
    end
  end
end

