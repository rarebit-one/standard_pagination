module StandardPagination
  # Offset pagination for MCP list tools, shared by every app's
  # ApplicationTool. MCP clients already consume this shape, so it keeps the
  # `per_page`/`total_count`/`total_pages` keys rather than the controller's.
  module Mcp
    DEFAULT_PER_PAGE = 20
    MAX_PER_PAGE = 100

    module_function

    # Returns `[records, { page:, per_page:, total_count:, total_pages: }]`.
    # A page past the end returns no records rather than raising.
    def paginate(scope, page: 1, per_page: DEFAULT_PER_PAGE, max_per_page: MAX_PER_PAGE, tiebreak: nil)
      tiebreak = StandardPagination.config.tiebreak if tiebreak.nil?
      page = [ page.to_i, 1 ].max
      per_page = per_page.to_i
      per_page = DEFAULT_PER_PAGE unless per_page.positive?
      per_page = per_page.clamp(1, max_per_page)

      total = count(scope)
      scope = StableOrder.apply(scope) if tiebreak
      records = scope.offset((page - 1) * per_page).limit(per_page).to_a

      [ records, { page:, per_page:, total_count: total, total_pages: (total.to_f / per_page).ceil } ]
    end

    def count(scope)
      # `select("DISTINCT ...")` returns fewer rows than count(:all) counts,
      # so count the projected result set instead.
      if StableOrder.inline_distinct?(scope)
        return scope.klass.unscoped.from(scope.unscope(:order), :subquery).count
      end

      total = scope.count(:all)
      # GROUP BY relations count to a Hash of group => count; the number of
      # groups is the number of rows being paged over.
      total.is_a?(Hash) ? total.size : total
    end
  end
end
