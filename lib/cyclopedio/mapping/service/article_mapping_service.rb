require_relative 'mapping_service'

module Cyclopedio
  module Mapping
    module Service
      class ArticleMappingService < MappingService
        # Returns a row with the article name supplemented with values of contextual
        # support for a given article - term mapping.
        def candidates_for_article(article)
          candidate_set = @candidate_generator.article_candidates(article)
          result = [article.name]
          report(article.name.hl(:blue))
          return result if candidate_set.empty?
          candidate_set.candidates.each do |term|
            parent_candidates = related_category_candidates(@context_provider.context(article).categories.values.flatten(1).uniq)
            genus_candidates = [@candidate_generator.genus_proximum_candidates(article)]
            type_candidates = related_type_candidates([article])
            parentheses_candidates = [@candidate_generator.parentheses_candidates(article)]
            counts = []
            counts.concat(number_of_matched_candidates(parent_candidates, term, article.name, [:isa?, :genls?]))
            counts.concat(number_of_matched_candidates(genus_candidates, term, genus_candidates.first.full_name, [:isa?, :genls?]))
            counts.concat(number_of_matched_candidates(type_candidates, term, 'DBPEDIA_TYPE', [:genls?, :spec?]))
            counts.concat(number_of_matched_candidates(parentheses_candidates, term, parentheses_candidates.first.full_name, [:isa?, :genls?]))
            positive, negative = sum_counts(counts, %w{p g t r})
            result.concat([term.id, term.to_ruby.to_s, positive, positive+negative])
          end
          result
        end
      end
    end
  end
end

