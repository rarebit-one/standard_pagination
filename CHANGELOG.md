# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-10-25

### Added
- `config.limit_key` accepts an Array of aliases, e.g. `%w[limit per_page]`; the first one the request sends wins. For APIs whose clients use both (luminality-web). The out-of-range redirect drops all of them.

### Fixed
- `Controller#paginate` raised `NoMethodError` (`select_values` for Array) when given an in-memory Array, such as an assembled audit timeline. The inline-DISTINCT count check added late in 0.1.0 assumed an ActiveRecord relation. Arrays paginate again, and a spec covers them. Found while adopting the gem in fundbright-web.

## [0.1.0] - 2026-10-25

### Added
- `StandardPagination::Controller`, a concern that adds:
  - `paginate`, which wraps `pagy`. HTML pages ignore a client-chosen page size, JSON lets clients choose one up to `config.max_limit`, and the primary key is appended as a tie-breaker. It also neutralises any `max_limit`/`client_limit` left in `Pagy::OPTIONS` for that call.
  - `pagination_data`, which returns the standard `data_hash` keys.
  - `rescue_pagination_errors(html:, notice:)`: a 400 for JSON; for HTML a redirect that keeps filters (and answers 400 rather than redirect to the same failing URL), a 404, or a custom method. Declaring it again replaces the earlier handler.
- `StandardPagination::Mcp.paginate`, the MCP list helper, which keeps the `page`/`per_page`/`total_count`/`total_pages` shape. A non-positive or junk `per_page` now falls back to the default instead of becoming 1.
- `StandardPagination::StableOrder` and `StandardPagination::Model#stable_order`.
- A Railtie boot check for leftover client-limit options in `Pagy::OPTIONS`.
- Tested against pagy 43.6 and 43.8.
