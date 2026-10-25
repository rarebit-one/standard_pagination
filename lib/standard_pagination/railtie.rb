require "rails/railtie"

module StandardPagination
  class Railtie < ::Rails::Railtie
    # Runs after the app's config/initializers, so it sees the app's
    # Pagy::OPTIONS. Raises in development and test (so CI catches it) and
    # logs elsewhere, unless config.strict_options says otherwise.
    config.after_initialize do
      strict = StandardPagination.config.strict_options
      strict = Rails.env.local? if strict.nil?

      message = StandardPagination.check_pagy_options!(raise_error: strict)
      Rails.logger&.warn("[standard_pagination] #{message}") if message
    end
  end
end
