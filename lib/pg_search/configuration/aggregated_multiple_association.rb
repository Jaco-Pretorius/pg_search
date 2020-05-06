# frozen_string_literal: true

module PgSearch
  class Configuration
    class AggregatedMultipleAssociation < Association
      def initialize(config, name, column_names)
        super(
          config.model,
          name,
          Array(column_names).map do |column_name, weight|
            ForeignColumn.new(column_name, weight, config.model, self)
          end
        )
      end

      def join(primary_key)
        "LEFT OUTER JOIN (#{relation(primary_key).to_sql}) #{subselect_alias} ON #{subselect_alias}.id = #{primary_key}"
      end

      private

      def selects
        columns.map do |column|
          "string_agg(#{column.full_name}::text, ' ') AS #{column.alias}"
        end.join(", ")
      end

      def relation(primary_key)
        @model
          .unscoped
          .joins(@name)
          .select("#{primary_key} AS id, #{selects}")
          .group(primary_key)
      end
    end
  end
end

  # SELECT     "products"."id"                 AS id,
             # String_agg("tags"."name"::text, ' ') AS pg_search_9f77ffbdbddcb603b080a8
  # FROM       "products"
  # inner join "products_tags"
  # ON         "products_tags"."product_id" = "products"."id"
  # inner join "tags"
  # ON         "tags"."id" = "products_tags"."tag_id"
  # GROUP BY   "products"."id") pg_search_455a24ed3ca763c7a72181
