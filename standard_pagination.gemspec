require_relative "lib/standard_pagination/version"

Gem::Specification.new do |spec|
  spec.name        = "standard_pagination"
  spec.version     = StandardPagination::VERSION
  spec.authors     = [ "Jaryl Sim" ]
  spec.email       = [ "code@jaryl.dev" ]
  spec.homepage    = "https://github.com/rarebit-one/standard_pagination"
  spec.summary     = "Shared pagination conventions for Rails apps, built on pagy."
  spec.description = "StandardPagination wraps pagy with one controller concern, one metadata shape, safe page-size handling, out-of-range error handling, deterministic tie-broken ordering, and an MCP list helper shared across Rails apps."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/rarebit-one/standard_pagination"
  spec.metadata["changelog_uri"] = "https://github.com/rarebit-one/standard_pagination/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/rarebit-one/standard_pagination/issues"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["lib/**/*", "LICENSE", "Rakefile", "README.md", "CHANGELOG.md"]
  end

  spec.required_ruby_version = ">= 4.0"

  # 43.6 is the oldest pagy any consumer runs (luminality-web). Both 43.6
  # (`max_limit`) and 43.7 (`client_limit`) read the client page size from a
  # different option; Controller#paginate neutralises both, so either works.
  spec.add_dependency "pagy", ">= 43.6", "< 44"
  spec.add_dependency "activerecord", ">= 8.1"
  spec.add_dependency "actionpack", ">= 8.1"
  spec.add_dependency "railties", ">= 8.1"

  spec.add_development_dependency "brakeman"
  spec.add_development_dependency "bundler-audit"
  spec.add_development_dependency "simplecov"
end
