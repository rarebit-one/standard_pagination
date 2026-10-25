module StandardPagination
  # Offset pagination over a non-unique ORDER BY can repeat or skip rows
  # between pages: Postgres returns equal-sorting rows in any order, and that
  # order can differ between the OFFSET 0 and OFFSET 20 queries. Appending the
  # primary key makes the order total.
  module StableOrder
    DESC_PATTERN = /\bdesc\b/i

    module_function

    # Returns the relation with the primary key appended to its ORDER BY,
    # in the direction of the last existing sort key. Returns it unchanged
    # when that is unnecessary or would be unsafe:
    #
    # - not an ActiveRecord::Relation (arrays, search results)
    # - no single-column primary key
    # - already ordered by the primary key
    # - GROUP BY (the key isn't in the group, so Postgres rejects it)
    # - DISTINCT with a custom SELECT, including `select("DISTINCT ...")`
    #   (the key may not be selected)
    # - a custom FROM (the table name may not resolve)
    def apply(relation)
      return relation unless tiebreakable?(relation)

      primary_key = relation.klass.primary_key
      return relation if ordered_by?(relation, primary_key)

      attribute = relation.klass.arel_table[primary_key]
      relation.order(descending?(relation.order_values.last) ? attribute.desc : attribute.asc)
    end

    def tiebreakable?(relation)
      return false unless defined?(::ActiveRecord::Relation) && relation.is_a?(::ActiveRecord::Relation)
      return false unless relation.klass.primary_key.is_a?(String)
      return false if relation.group_values.any?
      return false if relation.distinct_value && relation.select_values.any?
      return false if inline_distinct?(relation)

      relation.from_clause.empty?
    end

    # `select("DISTINCT category")` leaves distinct_value unset.
    def inline_distinct?(relation)
      relation.select_values.any? { |value| !value.is_a?(Symbol) && value.to_s.match?(/\bdistinct\b/i) }
    end

    def ordered_by?(relation, primary_key)
      table = relation.klass.table_name
      pattern = /\A\s*(?:"?#{Regexp.escape(table)}"?\.)?"?#{Regexp.escape(primary_key)}"?(?:\s+(?:asc|desc))?\s*\z/i

      relation.order_values.any? do |value|
        node = value.is_a?(Arel::Nodes::Ordering) ? value.expr : value
        case node
        when Arel::Attributes::Attribute
          node.name.to_s == primary_key && node.relation.name.to_s == table
        when String, Symbol
          node.to_s.split(",").any? { |part| part.match?(pattern) }
        else
          false
        end
      end
    end

    def descending?(value)
      case value
      when Arel::Nodes::Descending then true
      when Arel::Nodes::Ordering then false
      when String, Arel::Nodes::SqlLiteral then value.to_s.split(",").last.to_s.match?(DESC_PATTERN)
      else false
      end
    end
  end
end
