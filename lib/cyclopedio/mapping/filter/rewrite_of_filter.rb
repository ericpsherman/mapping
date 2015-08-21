require_relative 'cyc_filter'

module Cyclopedio
  module Mapping
    module Filter
      # Filters all collections that are in relation "rewriteOf" with other collections in the set.
      class RewriteOfFilter < CycFilter
        # Remove terms that are in relation "rewriteOf" with other terms.

        def initialize(options)
          super
          @name_service = options[:name_service] || Cyc::Service::NameService.new(self.cyc)
        end

        def apply(terms)
          denied_terms = []
          terms.each do |term|
            result = cyc.cyc_query(-> { '`(#$rewriteOf '+term.to_cyc(true)+' ?s)' }, :UniversalVocabularyMt) || []
            # sometimes rewriteOf is identical on both sides
            next if result[0] && term.to_ruby == result[0][0][1..-1]
            rewrite_of = result.map { |e| @name_service.convert_ruby_term(extract_term_name(e.first)) }
            denied_terms.concat(rewrite_of)
          end
          terms.reject { |t| denied_terms.include?(t) }
        end

        private
        # Extracts term name from a result that might be either Lisp pair or Lisp
        # list.
        def extract_term_name(expression)
          if expression[1] == "."
            expression[2]
          else
            expression[1..-1]
          end
        end
      end
    end
  end
end

