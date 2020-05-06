# frozen_string_literal: true

module PgSearch
  class Configuration
    class SingularAssociation < Association
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
          "#{column.full_name}::text AS #{column.alias}"
        end.join(", ")
      end

      def relation(primary_key)
        @model.unscoped.joins(@name).select("#{primary_key} AS id, #{selects}")
      end
    end
  end
end
