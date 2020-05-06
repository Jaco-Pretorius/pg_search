# frozen_string_literal: true

module PgSearch
  class Configuration
    class MultipleAssociation < Association
      def initialize(config, name, column_names)
        super(config.model, name, []) # Filtering is done inside the subselect, so don't expose any columns
        @column_names = column_names
        @config = config
      end

      def join(primary_key)
        "LEFT OUTER JOIN (#{relation(primary_key).to_sql}) #{subselect_alias} ON #{subselect_alias}.id = #{primary_key}"
      end

      private

      def relation(primary_key)
        @model
          .unscoped
          .joins(@name)
          .select("#{primary_key} AS id, MAX(#{rank}) AS #{Configuration.alias(table_name, @name, "rank")}")
          .where(conditions)
          .group(primary_key)
      end

      def conditions
        @config
          .features
          .reject { |_feature_name, feature_options| feature_options && feature_options[:sort_only] }
          .map { |feature_name, _feature_options| feature_for(feature_name).conditions }
          .inject { |accumulator, expression| Arel::Nodes::Or.new(accumulator, expression) }
      end

      FEATURE_CLASSES = {
        dmetaphone: Features::DMetaphone,
        tsearch: Features::TSearch,
        trigram: Features::Trigram
      }.freeze

      def feature_for(feature_name)
        feature_name = feature_name.to_sym
        feature_class = FEATURE_CLASSES[feature_name]

        raise ArgumentError, "Unknown feature: #{feature_name}" unless feature_class

        normalizer = Normalizer.new(@config)

        association_class = @config.model.reflect_on_association(@name).klass
        columns = Array(@column_names).map do |column_name, weight|
          Column.new(column_name, weight, association_class)
        end

        feature_class.new(
          @config.query,
          @config.feature_options[feature_name],
          columns,
          association_class,
          normalizer
        )
      end

      def rank
        (@config.ranking_sql || ":tsearch").gsub(/:(\w*)/) do
          feature_for(Regexp.last_match(1)).rank.to_sql
        end
      end
    end
  end
end

# SELECT     "products"."id"                 AS id,
           # MAX(
            # (Ts_rank((To_tsvector('simple', Coalesce("tags"."name"::text, ''))), (To_tsquery('simple', ''' '
               # || 'QueryString'
               # || ' '''
               # || ':*')), 0))
           # ) AS pg_search_9f77ffbdbddcb603b080a8
# FROM       "products"
# inner join "products_tags"
# ON         "products_tags"."product_id" = "products"."id"
# inner join "tags"
# ON         "tags"."id" = "products_tags"."tag_id"
# WHERE (To_tsvector('simple', Coalesce("tags"."name"::text, ''))) @@ (To_tsquery('simple', ''' ' || 'QueryString' || ' ''' || ':*'))
# GROUP BY   "products"."id") pg_search_455a24ed3ca763c7a72181
