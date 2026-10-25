module StandardPagination
  class Config
    # Rows per page when a call site passes no `limit:`.
    attr_accessor :default_limit
    # Largest page size a client may request when client limits are on.
    attr_accessor :max_limit
    # Request param a client sets the page size with (when allowed).
    attr_accessor :limit_key
    # Formats for which `paginate` honours the client's page size by default.
    # HTML pages keep the size the call site chose.
    attr_accessor :client_limit_formats
    # Pagy raises Pagy::RangeError for a page past the last one, which
    # Controller.rescue_pagination_errors turns into a redirect, 404 or 400.
    # With it off, pagy serves an empty page instead.
    attr_accessor :raise_range_error
    # `paginate` appends the primary key to the ORDER BY unless told not to.
    attr_accessor :tiebreak
    # Raise (rather than warn) at boot when Pagy::OPTIONS still sets a
    # client-limit option. Defaults to true in development and test only.
    attr_accessor :strict_options

    def initialize
      @default_limit = 20
      @max_limit = 100
      @limit_key = "limit"
      @client_limit_formats = %i[json]
      @raise_range_error = true
      @tiebreak = true
      @strict_options = nil
    end
  end
end
