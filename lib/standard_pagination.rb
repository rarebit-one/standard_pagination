require "pagy"
require "active_support"
require "active_support/core_ext/module/attribute_accessors"

require "standard_pagination/version"
require "standard_pagination/config"
require "standard_pagination/stable_order"
require "standard_pagination/mcp"

module StandardPagination
  class ConfigurationError < StandardError; end

  # The one metadata shape every Inertia prop and JSON list sends. pagy's
  # `data_hash` omits a key whose value is nil, so `previous`/`next` are absent
  # on the first/last page rather than null; consumers' TypeScript types
  # already treat them as optional.
  DATA_KEYS = %i[page pages count limit from to previous next].freeze

  # Global pagy options that make pagy read the page size from the request.
  # 43.6 reads `max_limit`; 43.7 reads `client_limit` and maps the other two
  # onto it with a deprecation warning on every call.
  CLIENT_LIMIT_OPTIONS = %i[max_limit client_limit client_max_limit].freeze

  class << self
    def config
      @config ||= Config.new
    end

    def configure
      yield config
    end

    def reset_config!
      @config = Config.new
    end

    def data(pagy)
      pagy.data_hash(data_keys: DATA_KEYS)
    end

    # The one cursor envelope for feeds, alongside the records as `data`:
    # `{ next_cursor: "<opaque>" | nil, has_more: true | false }`.
    def cursor_data(pagy)
      next_cursor = pagy.next
      { next_cursor:, has_more: !next_cursor.nil? }
    end

    # Global pagy client-limit options left over from before this gem. They
    # still apply to any bare `pagy(...)` call that bypasses
    # Controller#paginate, letting clients pick the page size.
    def leftover_client_limit_options(options = Pagy::OPTIONS)
      CLIENT_LIMIT_OPTIONS.select { |key| options.key?(key) }
    end

    def check_pagy_options!(options = Pagy::OPTIONS, raise_error: true)
      leftovers = leftover_client_limit_options(options)
      return if leftovers.empty?

      message = "Pagy::OPTIONS sets #{leftovers.map(&:inspect).join(', ')}, which lets clients choose the page " \
                "size on every bare `pagy` call. Remove it and use `paginate(..., client_limit:)` instead."
      raise ConfigurationError, message if raise_error

      message
    end
  end
end

require "standard_pagination/controller"
require "standard_pagination/model"
require "standard_pagination/railtie" if defined?(Rails::Railtie)
