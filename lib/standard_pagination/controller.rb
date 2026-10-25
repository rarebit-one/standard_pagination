require "active_support/concern"
require "action_controller"

module StandardPagination
  # Include in ApplicationController (and any API base controller that does not
  # inherit from it):
  #
  #   include StandardPagination::Controller
  #   rescue_pagination_errors html: :redirect   # last, after any catch-alls
  #
  #   pagy, records = paginate(Device.where(...).order(created_at: :desc))
  #   render inertia: "devices/index", props: { devices: ..., pagination: pagination_data(pagy) }
  module Controller
    extend ActiveSupport::Concern

    HTML_STRATEGIES = %i[redirect not_found].freeze

    included do
      include Pagy::Method

      class_attribute :_pagination_error_handling, instance_accessor: false, default: nil
    end

    class_methods do
      # Turns Pagy::OptionError (and its subclass Pagy::RangeError) into a
      # response instead of a 500.
      #
      # JSON requests get a 400 with `last_page` (an integer for an
      # out-of-range page, null for any other bad option). HTML requests,
      # depending on `html:`:
      #
      # - `:redirect` redirects to the last page, keeping every other query
      #   param so filters survive. For a bad option other than the page, it
      #   drops the page and limit params instead, so the redirect can't loop.
      # - `:not_found` responds 404 with an empty body.
      # - a Symbol naming a controller method calls it with the exception,
      #   e.g. `html: :render_not_found` for an app's own 404 page.
      #
      # `notice:` is the flash for the redirect: a String, or a Proc evaluated
      # in the controller (for I18n).
      #
      # Rails looks rescue handlers up from last-declared to first, so call
      # this after any `rescue_from StandardError`. Calling it again replaces
      # the earlier registration rather than stacking a second handler.
      def rescue_pagination_errors(html: :redirect, notice: nil)
        self._pagination_error_handling = { html:, notice: }

        self.rescue_handlers = rescue_handlers.reject { |handler| handler.first == "Pagy::OptionError" }
        rescue_from Pagy::OptionError, with: :handle_pagination_error
      end
    end

    private

    # Paginates `collection` with pagy and returns `[pagy, records]`.
    #
    # - `limit:` is the page size for this call (default: config.default_limit).
    # - `client_limit:` lets the request override the page size via the
    #   config.limit_key param, capped at an Integer, or at config.max_limit
    #   for `true`. It defaults to on for config.client_limit_formats (JSON)
    #   and off for HTML, so an HTML page always shows the size it chose.
    #   A non-positive or non-numeric request value falls back to `limit:`.
    # - `tiebreak:` appends the primary key to the ORDER BY (StableOrder).
    # - `paginator:` is passed through to pagy (`:offset`, `:countless`, ...),
    #   as is any other pagy option (`page_key:`, `count:`, ...).
    #
    # Global client-limit options in Pagy::OPTIONS are neutralised for this
    # call, so only `client_limit:` decides whether the client picks the size.
    def paginate(collection, limit: nil, client_limit: nil, tiebreak: nil, paginator: :offset, **options)
      config = StandardPagination.config
      tiebreak = config.tiebreak if tiebreak.nil?
      collection = StableOrder.apply(collection) if tiebreak

      pagy(
        paginator,
        collection,
        raise_range_error: config.raise_range_error,
        **options,
        limit: resolve_pagination_limit(limit || config.default_limit, client_limit),
        max_limit: nil,
        client_limit: nil,
        client_max_limit: nil
      )
    end

    def pagination_data(pagy)
      StandardPagination.data(pagy)
    end

    def resolve_pagination_limit(limit, client_limit)
      cap = pagination_client_limit_cap(client_limit)
      return limit unless cap

      requested = params[StandardPagination.config.limit_key].to_s
      return limit unless requested.match?(/\A\d+\z/) && requested.to_i.positive?

      [ requested.to_i, cap ].min
    end

    def pagination_client_limit_cap(client_limit)
      client_limit = pagination_client_limit_format? if client_limit.nil?

      case client_limit
      when Integer then client_limit
      when true then StandardPagination.config.max_limit
      end
    end

    def pagination_client_limit_format?
      formats = StandardPagination.config.client_limit_formats
      formats.any? { |format| request.format.public_send(:"#{format}?") }
    end

    def handle_pagination_error(exception)
      handling = self.class._pagination_error_handling || {}
      last_page = exception.is_a?(Pagy::RangeError) ? exception.pagy&.last : nil

      if request.format.json?
        return render json: { error: pagination_error_message(exception), last_page: }, status: :bad_request
      end

      case handling.fetch(:html, :redirect)
      when :redirect then redirect_after_pagination_error(exception, last_page, handling[:notice])
      when :not_found then head :not_found
      else send(handling[:html], exception)
      end
    end

    def pagination_error_message(exception)
      exception.is_a?(Pagy::RangeError) ? "Page out of range" : "Invalid pagination parameters"
    end

    def redirect_after_pagination_error(exception, last_page, notice)
      options = exception.pagy&.options || {}
      page_key = (options[:page_key] || Pagy::DEFAULT[:page_key]).to_s
      query = request.query_parameters.except(page_key)

      if last_page
        query[page_key] = last_page
      else
        query = query.except((options[:limit_key] || Pagy::DEFAULT[:limit_key]).to_s, StandardPagination.config.limit_key)
      end

      # Rebuild the URL from the current route rather than request.path, so a
      # crafted path ("//evil.example") can't become an off-site redirect.
      location = url_for(request.path_parameters.merge(query.symbolize_keys, only_path: true))
      notice = instance_exec(&notice) if notice.respond_to?(:call)
      flash = notice ? { notice: } : {}
      redirect_to(location, allow_other_host: false, **flash)
    end
  end
end
