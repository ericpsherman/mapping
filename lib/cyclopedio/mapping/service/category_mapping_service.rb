require_relative 'mapping_service'

module Cyclopedio
  module Mapping
    module Service
      class CategoryMappingService < MappingService

        # Category specific options:
        # * :multiplier: - service used to find most specific generalizations for
        #   categories with multiple heads.
        def initialize(options)
          super(options)
          @multiplier = options[:multiplier]
        end

        # Returns a row with the category name, the names that were used to find
        # the candidates and Cyc candidates supplemented with values of contextual
        # support for a given category - term mapping.
        def candidates_for_category(category)
          candidate_set = @candidate_generator.category_candidates(category)
          row = [category.name,candidate_set.full_name]
          report(category.name.hl(:blue))
          if candidate_set.size > 1
            report(candidate_set.all_candidates.to_s.hl(:purple))
            candidates = @multiplier.multiply(candidate_set)
            report(candidates.to_s.hl(:purple))
          else
            candidates = candidate_set.candidates
          end
          if candidates && !candidates.empty?
            # related candidate sets
            context = @context_provider.context(category)
            parent_candidate_sets = related_category_candidates(context.parents.values.flatten(1).uniq)
            child_candidate_sets = related_category_candidates(context.children.values.flatten(1).uniq)
            articles = context.articles.values.flatten(1).uniq
            instance_candidate_sets = related_article_candidates(articles)
            type_candidate_sets = related_type_candidates(articles)
            infobox_candidate_sets = related_infobox_candidates(articles)
            # matched relations computation
            candidates.each do |term|
              counts = []
              counts.concat(number_of_matched_candidates(parent_candidate_sets,term,candidate_set.full_name,[:genls?])
              counts.concat(number_of_matched_candidates(child_candidate_sets,term,candidate_set.full_name,[:spec?])
              counts.concat(number_of_matched_candidates(instance_candidate_sets,term,candidate_set.full_name,[:type?])
              counts.concat(number_of_matched_candidates(type_candidate_sets,term,"DBPEDIA_TYPE"),[:genls?,:spec?,:isa?,:type?])
              counts.concat(number_of_matched_candidates(infobox_candidate_sets,term,"INFOBOX"),[:genls?,:spec?,:isa?,:type?])
              sum_counts(counts,%w{p c i t x})
              row.concat([term.id,term.to_ruby,positive,positive+negative])
            end
          end
          row
        end
      end
    end
  end
end

