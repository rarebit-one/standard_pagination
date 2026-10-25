# StandardPagination

Shared pagination conventions for the estate's Rails apps, built on [pagy](https://github.com/ddnexus/pagy) 43.

Before this gem, sidekick-web, nutripod-web, fundbright-web and luminality-web each kept their own copy of the same helpers, and shared the same bugs:

- **Clients could set the page size on every list.** Each app's `Pagy::OPTIONS[:max_limit] = 100` became pagy 43.7's `client_limit`, which lets a client pick any page size up to 100 with `?limit=`, even where the call site fixed one.
- **Rows repeated or went missing between pages.** Lists sorted only on a timestamp, so equal rows could land in a different order on the next page's query.
- **Errors returned 500 or looped.** JSON APIs had no pagy rescue, and an HTML redirect could lose filters or loop.

The gem provides one copy of each helper, and these fixes:

| Piece | What it does |
|---|---|
| `StandardPagination::Controller` | `paginate` and `pagination_data`. HTML pages keep the page size the call site sets, and JSON clients may choose one up to a cap. It adds an id tie-breaker and lets you opt in to `rescue_pagination_errors`. |
| `StandardPagination::Mcp.paginate` | The MCP list-tool helper every app's `ApplicationTool` carried a copy of. It keeps the same response shape. |
| `StandardPagination::StableOrder` / `Model#stable_order` | Appends the primary key to an ORDER BY when that is safe. |
| Railtie | At boot, flags a leftover `max_limit` or `client_limit` in `Pagy::OPTIONS`. It raises in development and test, and logs elsewhere. |

## Install

```ruby
gem "standard_pagination", "~> 0.1"
```

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include StandardPagination::Controller   # includes Pagy::Method

  rescue_from StandardError, with: :render_error   # catch-alls first...
  rescue_pagination_errors html: :redirect          # ...then this, so it wins
end

# app/models/application_record.rb
class ApplicationRecord < ActiveRecord::Base
  include StandardPagination::Model
end
```

Delete `max_limit` (or `client_limit`) from `config/initializers/pagy.rb`. Leave `raise_range_error` out as well: `paginate` passes `config.raise_range_error`, which defaults to `true`.

```ruby
# config/initializers/standard_pagination.rb (optional; these are the defaults)
StandardPagination.configure do |c|
  c.default_limit = 20            # rows when a call site passes no limit:
  c.max_limit = 100               # cap on a client-chosen page size
  c.limit_key = "limit"           # param a client sets it with ("per_page" in luminality)
  c.client_limit_formats = %i[json]
  c.tiebreak = true
  c.raise_range_error = true
  c.strict_options = nil          # nil = raise in dev/test, log elsewhere
end
```

## Controllers

```ruby
pagy, devices = paginate(Device.where(zone:).order(created_at: :desc), limit: 25)

render inertia: "factory/devices/index", props: {
  devices: devices.map { DeviceSerializer.new(_1) },
  pagination: pagination_data(pagy)
}
```

`pagination_data` returns `{ page, pages, count, limit, from, to, previous, next }`. `previous` and `next` are left out on the first and last page, as pagy's `data_hash` always did. It is the shape every app's `PaginationMetadata` TypeScript type already describes.

`paginate` options:

- `limit:` is the page size. It defaults to `config.default_limit`.
- `client_limit:` lets the request set the page size through `config.limit_key`. Pass an Integer cap, `true` for `config.max_limit`, or `false` to turn it off. It defaults to on for JSON and off for HTML. A request value that is junk, zero or negative falls back to `limit:`.
- `tiebreak:` defaults to `config.tiebreak`.
- `paginator:` defaults to `:offset`. `:countless` skips the `COUNT(*)` on big append-only tables. Any other pagy option, such as `page_key:` or `count:`, passes through.

For several tables on one page, give each its own `page_key:`:

```ruby
pagy_new, new_apps = paginate(new_scope, page_key: "new_page")
pagy_done, done_apps = paginate(done_scope, page_key: "done_page")
```

### Errors

`rescue_pagination_errors` handles `Pagy::OptionError`, which includes its subclass `Pagy::RangeError`.

| Request | Out-of-range page | Any other bad option |
|---|---|---|
| JSON | 400 `{ error: "Page out of range", last_page: 4 }` | 400 `{ error: "Invalid pagination parameters", last_page: null }` |
| HTML, `html: :redirect` | Redirects to the last page, keeping every other param | Redirects without the page and limit params, so it can't loop |
| HTML, `html: :not_found` | 404 | 404 |
| HTML, `html: :my_method` | Calls `my_method(exception)` | Calls `my_method(exception)` |

`notice:` sets the redirect's flash. Pass a String, or a Proc for I18n: `notice: -> { t("flash.application.pagination_out_of_range") }`.

## Ordering

`paginate` and `Mcp.paginate` append the primary key in the direction of the last sort key:

```sql
ORDER BY occurred_at DESC              -- before
ORDER BY occurred_at DESC, id DESC     -- after
```

An unordered relation gets `ORDER BY id ASC`. The relation is left alone when the key is already in the order, and in these unsafe cases:

- it has a `GROUP BY`
- it uses `DISTINCT` with a custom `SELECT`
- it has a custom `FROM`
- the model's primary key is composite

Outside a paginator (a query object, or an engine scope a host will page through), use `Model.stable_order(...)`, for example `AuditLog.where(...).stable_order(occurred_at: :desc)`.

## MCP tools

```ruby
# lib/mcp/tools/application_tool.rb
def paginate(scope, page: 1, per_page: DEFAULT_PER_PAGE)
  StandardPagination::Mcp.paginate(scope, page:, per_page:, max_per_page: MAX_PER_PAGE)
end
```

It returns `[records, { page:, per_page:, total_count:, total_pages: }]`, the shape MCP clients already parse. A `GROUP BY` relation counts its groups, and a page past the end returns no records.

## Not in 0.1

- **Keyset or cursor pagination for feeds and APIs.** Today these are hand-rolled in sidekick-web's companion queries and in jumpdrive. 0.2 is meant to settle on a single `next_cursor` / `has_more` envelope.
- **A shared React `<Pagination>` component.** It belongs in a frontend package, not a gem.

## Development

```bash
bundle exec rspec                                              # newest pagy
BUNDLE_GEMFILE=gemfiles/pagy-43.6.gemfile bundle exec rspec    # oldest a consumer runs
bundle exec rubocop
```
