require_relative 'mapping_service'

module Cyclopedio
  module Mapping
    module Service
      class PatternMappingService < MappingService

        # Options:
        # * :multiplier: - service used to find most specific generalizations for
        #   categories with multiple heads
        # * :sample_size: - the number of categories matching the pattern used
        #   to compute the disambiguation support.
        def initialize(options)
          @multiplier = options[:multiplier]
          @sample_size = options[:sample_size]
        end

        def candidates_for_pattern(pattern,head,category_ids,support)
          representative_id = category_ids.find do |category_wiki_id|
            category = Category.find_by_wiki_id(category_wiki_id)
            next unless category.plural? && category.regular?
            category.head == head
          end
          return [] if representative_id.nil?
          representative = Category.find_by_wiki_id(representative_id)
          candidate_set = @candidate_generator.pattern_candidates(pattern,representative)
          row = [pattern,candidate_set.full_name,support]
          report(pattern.hl(:blue))
          if candidate_set.size > 1
            report(candidate_set.all_candidates.to_s.hl(:purple))
            candidates = @multiplier.multiply(candidate_set)
            report(candidates.to_s.hl(:purple))
          else
            candidates = candidate_set.candidates
          end
          if candidates && !candidates.empty?
            # related candidate sets
            parents = Set.new
            children = Set.new
            articles = Set.new
            context = @context_provider.context(category)
            category_ids.sample(@sample_size).each do |category_wiki_id|
              category = Category.find_by_wiki_id(category_wiki_id)
              parents.merge(context.parents.values.flatten(1))
              children.merge(context.children.values.flatten(1))
              articles.merge(context.articles.values.flatten(1))
            end
            parent_candidate_sets = related_category_candidates(parents.to_a)
            child_candidate_sets = related_category_candidates(children.to_a)
            instance_candidate_sets = related_article_candidates(articles.to_a)
            type_candidate_sets = related_type_candidates(articles.to_a)
            # matched relations computation
            candidates.each do |term|
              counts = []
              counts.concat(number_of_matched_candidates(parent_candidate_sets,term,candidate_set.full_name,[:genls?]))
              counts.concat(number_of_matched_candidates(child_candidate_sets,term,candidate_set.full_name,[:spec?])
              counts.concat(number_of_matched_candidates(instance_candidate_sets,term,candidate_set.full_name,[:type?])
              counts.concat(number_of_matched_candidates(type_candidate_sets,term,"DBPEDIA_TYPE",[:genls?,:spec?,:isa?,:type?]])
              sum_counts(counts,%w{p c i t})
              row.concat([term.id,term.to_ruby,positive,positive+negative])
            end
          end
          row
        end
      end
    end
  end
end

