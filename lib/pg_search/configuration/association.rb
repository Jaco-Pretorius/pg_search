# frozen_string_literal: true

module PgSearch
  class Configuration
    class Association
      class << self
        def build(config, name, column_names)
          if %i[has_one belongs_to].include?(config.model.reflect_on_association(name).macro)
            SingularAssociation.new(config, name, column_names)
          elsif config.aggregate_associations
            AggregatedMultipleAssociation.new(config, name, column_names)
          else
            MultipleAssociation.new(config, name, column_names)
          end
        end
      end

      attr_reader :columns

      def initialize(model, name, columns)
        @model = model
        @name = name
        @columns = columns
      end

      def table_name
        @model.reflect_on_association(@name).table_name
      end

      def subselect_alias
        Configuration.alias(table_name, @name, "subselect")
      end
    end
  end
end
