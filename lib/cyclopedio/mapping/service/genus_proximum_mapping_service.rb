require_relative 'mapping_service'

module Cyclopedio
  module Mapping
    module Service
      class GenusProximumMappingService < MappingService
        # Returns a row with the article name, the names that were used to find
        # the candidates and Cyc candidates supplemented with values of contextual
        # support for a given article - type mapping.
        def candidates_for_article(article)
          candidate_set = @candidate_generator.genus_proximum_candidates(article)
          result = [article.name]
          report(article.name.hl(:blue))
          return result if candidate_set.empty?
          candidate_set.each do |name, candidates|
            result.concat(['T', name])
            puts name if @verbose
            name = name.downcase.singularize
            next if candidates.empty?
            parent_candidates = related_category_candidates(@context_provider.context(article).categories.values.flatten(1).uniq)
            type_candidates = related_type_candidates([article])
            parentheses_candidates = [@candidate_generator.parentheses_candidates(article)]
            candidates.each do |term|
              counts = []
              counts.concat(number_of_matched_candidates(parent_candidates, term, name, [:genls?, :spec?]))
              counts.concat(number_of_matched_candidates(type_candidates, term, 'DBPEDIA_TYPE', [:genls?, :spec?]))
              counts.concat(number_of_matched_candidates(parentheses_candidates, term, parentheses_candidates.first.full_name, [:genls?, :spec?]))
              positive, negative = sum_counts(counts, %w{p t r})
              result.concat([term.id, term.to_ruby.to_s, positive, positive+negative])
            end
          end
          result
        end
      end
    end
  end
end

