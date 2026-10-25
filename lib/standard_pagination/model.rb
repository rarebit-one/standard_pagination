require "active_support/concern"

module StandardPagination
  # Include in ApplicationRecord to get a `stable_order` scope:
  #
  #   AuditLog.stable_order(occurred_at: :desc)
  #   # ORDER BY occurred_at DESC, id DESC
  #
  # Use it where an ordering leaves the paginator, e.g. a query object or an
  # engine scope that a host app will page through. Controller#paginate and
  # Mcp.paginate apply the same tie-breaker on their own.
  module Model
    extend ActiveSupport::Concern

    class_methods do
      def stable_order(*args)
        StableOrder.apply(order(*args))
      end
    end
  end
end
