module Cyclopedio
  module Mapping
    module Service
      class MappingService
        class Reporter
          def call(message)
            puts message
          end
        end

        # The options that have to be provided to the category mapping service:
        # * :candidate_generator: - service used to provide candidate terms for
        #   categories and articles
        # * :context_provider: - service used to provide context for the mapped
        #   category
        # * :cyc: - Cyc client
        # Optional:
        # * :verbose: - if set to true, diagnostic messages will be send to the
        #   reporter
        # * :reporter: - service used to print the messages
        def initialize(options={})
          @candidate_generator = options[:candidate_generator]
          @context_provider = options[:context_provider]
          @cyc = options[:cyc]
          @verbose = options[:verbose]
          @talkative = options[:talkative]
          @reporter = options[:reporter] || Reporter.new
        end

        protected
        # Checks if +source+ generalizes to +target+ according to Cyc.
        def genls?(source,target)
          @cyc.genls?(source,target)
        end

        # Checks if +source+ is a specialization of +target+ according to Cyc.
        def spec?(source,target)
          @cyc.genls?(target,source)
        end

        # Checks if +source+ is an instance of +target+ according to Cyc.
        def isa?(source,target)
          @cyc.with_any_mt{|cyc| cyc.isa?(source,target) }
        end

        # Checks if +source+ is an type of +target+ according to Cyc (i.e.
        # inversion of isa?).
        def type?(source,target)
          @cyc.with_any_mt{|cyc| cyc.isa?(target,source) }
        end

        def report(string="")
          if block_given?
            if @verbose
              yield @reporter
            end
          else
            @reporter.call(string) if @verbose
          end
        end

        def verbose_report(string="")
          if block_given?
            if @talkative
              yield @reporter
            end
          else
            @reporter.call(string) if @talkative
          end
        end

        def related_category_candidates(categories)
          categories.select{|c| c.regular? && c.plural?}.map{|c| @candidate_generator.category_candidates(c) }.
            reject{|candidate_set| candidate_set.empty? }
        end

        def related_article_candidates(articles)
          articles.select{|a| a.regular? }.map{|a| @candidate_generator.article_candidates(a) }.reject{|candidate_set| candidate_set.empty? }
        end

        def related_type_candidates(articles)
	  # TODO implement field for 'predefined' article type.
          [] || articles.select{|a| a.regular? && a.dbpedia_type }.map{|a| @candidate_generator.term_candidates(a.dbpedia_type.cyc_id) }
        end

        def number_of_matched_candidates(candidate_sets_for_related_terms,term,entity_name,relations)
          candidate_sets_for_related_terms.map do |candidate_set|
            next if candidate_set.full_name.downcase.singularize == entity_name.downcase.singularize || candidate_set.all_candidates.flatten.empty?
            verbose_report{|r| r.call "#{candidate_set.full_name} -> #{candidate_set.all_candidates.flatten.join(",")}" }
            evidence = candidate_set.all_candidates.flatten.find{|candidate| relations.any?{|r| self.send(r,term,candidate) } }
            if evidence
              verbose_report("#{entity_name.downcase.singularize} - #{candidate_set.full_name.downcase.singularize} - #{evidence.to_ruby}".hl(:yellow))
            end
            !!evidence
          end.compact.partition{|e| e }.map{|e| e.size }
        end

        #Counts positive and negative signals.
        def sum_counts(counts,labels)
          positive = counts.map.with_index { |e, i| e if i % 2 == 0 }.compact.inject(0) { |e, s| e + s }
          negative = counts.map.with_index { |e, i| e if i % 2 != 0 }.compact.inject(0) { |e, s| e + s }
          report do |reporter|
            if positive > 0
              labels = labels.map{|name| "#{name}:%i/%i" }.join(",")
              count_string = "  %-20s #{labels} -> %i/%i/%.1f" %
                  [term.to_ruby, *counts, positive, positive+negative, (positive/(positive+negative).to_f*100)] #TODO term?
              reporter.call(count_string.hl(:green))
            else
              reporter.call("  #{term.to_ruby}".hl(:red)) #TODO term?
            end
          end
          return positive, negative
        end
      end
    end
  end
end

