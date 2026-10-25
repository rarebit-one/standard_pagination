# AGENTS.md - AI Agent Guide for StandardPagination

StandardPagination wraps [pagy](https://github.com/ddnexus/pagy) 43 with the estate's pagination conventions: one controller concern (`paginate`, `pagination_data`, `rescue_pagination_errors`), one metadata shape, safe client page sizes, deterministic tie-broken ordering, and the MCP list helper. See `README.md` for usage.

## Quick Reference

```bash
bundle exec rspec                                              # newest pagy (Gemfile.lock)
BUNDLE_GEMFILE=gemfiles/pagy-43.6.gemfile bundle exec rspec    # oldest pagy a consumer runs
bundle exec rubocop -A
bundle exec brakeman --no-pager --force
bundle exec bundler-audit --update
```

## Project Structure

```
lib/standard_pagination.rb               # entry point, DATA_KEYS, config facade, boot check
lib/standard_pagination/config.rb        # defaults (limit 20, max 100, client limits for JSON)
lib/standard_pagination/controller.rb    # paginate / pagination_data / rescue_pagination_errors
lib/standard_pagination/stable_order.rb  # primary-key tie-breaker
lib/standard_pagination/model.rb         # Model.stable_order scope
lib/standard_pagination/mcp.rb           # MCP list helper (page/per_page/total_count/total_pages)
lib/standard_pagination/railtie.rb       # after_initialize Pagy::OPTIONS check
spec/support/test_app.rb                 # in-process Rails app on in-memory SQLite
```

## Key Patterns

- **pagy version drift.** 43.6 reads the client page size from `max_limit`; 43.7+ reads `client_limit` and maps `max_limit`/`client_max_limit` onto it with a warning. `Controller#paginate` resolves the limit itself and passes all three as `nil`, which neutralises a global setting on both versions. Keep both CI runs green when touching this.
- **Rescue ordering.** Rails matches `rescue_handlers` last-declared first, so `rescue_pagination_errors` re-appends its handler on every call (same pattern as `StandardCircuit::ControllerSupport#circuit_open_fallback`).
- **Response shapes are contracts.** `DATA_KEYS` matches every consumer's `PaginationMetadata` TypeScript type, and `Mcp.paginate`'s keys are what MCP clients parse. Changing either is a breaking change.
- **StableOrder only appends when safe** (no GROUP BY, no DISTINCT + custom SELECT, no custom FROM, single primary key). Add a spec for any new case before widening it.

## Dependencies

- **pagy** >= 43.6, < 44
- **activerecord**, **actionpack**, **railties** >= 8.1
