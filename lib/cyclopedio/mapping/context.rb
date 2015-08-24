module Cyclopedio
  module Mapping
    class Context
      # Creates context for the +entity+ with default context size set to
      # +default_distance+. The +remote_context+ service is used to fetch the
      # remote relative counterparts of the entity.
      def initialize(entity, default_distance, remote_context)
        @entity = entity
        @default_distance = default_distance
        @parents = Hash.new{|h,e| h[e] = [] }
        @children = Hash.new{|h,e| h[e] = [] }
        @articles = Hash.new{|h,e| h[e] = [] }
        @remote_context = remote_context
      end

      # Returns the parent categories of the entity. These are categories listed
      # at the end of the page in Wikipedia. If +max_distance+ is not provided,
      # default distance defined for this context is used. If the page is
      # emponymous, also the categories of the eponymous counterpart are
      # returned.
      def parents(max_distance=@default_distance)
        case @entity
        when Wiki::Category
          category_parents(max_distance)
        when Wiki::Article
          article_parents(max_distance)
        else
          raise ArgumentError.new("#{@entity} does not have parents in the context.")
        end
      end

      # Returns the child categories of the category. These are categories listed
      # at the category page. If +max_distance+ is not provided,
      # default distance defined for this context is used.
      def children(max_distance=@default_distance)
        @children[0] = [@entity] if @children[0].empty?
        add_relatives(@children,1,max_distance,:children)
        @children
      end

      # Returns the child articles of the category. These are articles listed
      # at the category page. If +max_distance+ is not provided,
      # default distance defined for this context is used.
      def articles(max_distance=@default_distance)
        1.upto(max_distance) do |distance|
          next if @articles.include?(distance)
          self.children(distance-1)[distance-1].each do |category|
            regular = category.articles.to_a
            remote = @remote_context.relatives(category, :articles, Cyclopedio::Wiki::Article)
            @articles[distance].concat(regular + remote)
          end
        end
        @articles
      end

      private
      # Returns parents of the entity which has to be a Wikipedia category, up
      # to +max_distance+.
      def category_parents(max_distance)
        @parents[0] = [@entity] if @parents[0].empty?
        add_relatives(@parents,1,max_distance,:parents){|r| r.eponymous_articles.flat_map{|a| a.categories.to_a } }
        @parents
      end

      # Returns parents of the entity which has to be a Wikipedia article, up
      # to +max_distance+.
      def article_parents(max_distance)
        if @parents.include?(max_distance)
          return @parents
        end

        # direct parents
        regular = @entity.categories.to_a
        eponymous = @entity.eponymous_categories.flat_map{|c| c.parents.to_a }
        remote = @remote_context.relatives(@entity, :categories, Cyclopedio::Wiki::Category)
        @parents[1] = (regular + eponymous + remote).select { |c| c.regular? && c.plural? }

        add_relatives(@parents,2,max_distance,:parents){|r| r.eponymous_articles.flat_map{|a| a.categories.to_a } }
        @parents
      end

      # Add relatives of type +relationship+ from +min_distance+ up to +max_distance+ from the
      # entity.
      def add_relatives(relatives,min_distance,max_distance,relationship)
        min_distance.upto(max_distance) do |distance|
          next if relatives.include?(distance)
          relatives[distance-1].each do |relative|
            regular = relative.public_send(relationship).to_a
            remote = @remote_context.relatives(relative, relationship, Cyclopedio::Wiki::Category)
            auxiliary = []
            auxiliary = yield(relative) if block_given?
            relatives[distance].concat((regular + remote + auxiliary).select { |c| c.regular? && c.plural? })
          end
        end
      end
    end
  end
end
