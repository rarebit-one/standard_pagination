require "spec_helper"
require "rack/test"

RSpec.describe StandardPagination::Controller do
  include Rack::Test::Methods

  def app = TestApp

  def json = JSON.parse(last_response.body)

  before do
    # Ranks tie in pairs, so only the id tie-breaker makes the order total.
    %w[a b c d e f g].each_with_index { |name, i| Widget.create!(name:, rank: i / 2) }
  end

  describe "#paginate" do
    it "uses the call site's limit and the standard metadata shape" do
      get "/widgets.json"

      expect(json["names"].size).to eq(2)
      expect(json["pagination"]).to include("page" => 1, "pages" => 4, "count" => 7, "limit" => 2, "from" => 1, "to" => 2, "next" => 2)
      expect(json["pagination"]).not_to have_key("previous")
    end

    it "falls back to config.default_limit" do
      StandardPagination.config.default_limit = 5
      get "/widgets.json", size: "default"

      expect(json["pagination"]["limit"]).to eq(5)
    end

    it "breaks ties on the primary key so pages never overlap" do
      names = (1..4).flat_map do |page|
        get "/widgets.json", page: page
        json["names"]
      end

      expect(names).to eq(%w[g f e d c b a])
    end

    it "lets JSON clients choose the page size up to config.max_limit" do
      StandardPagination.config.max_limit = 3
      get "/widgets.json", limit: 50

      expect(json["pagination"]["limit"]).to eq(3)
    end

    it "ignores the client's page size on HTML pages" do
      get "/widgets", limit: 5

      expect(last_response.body.split(",").size).to eq(2)
    end

    it "honours an explicit client_limit cap on HTML pages" do
      get "/widgets", limit: 5, client: "4"

      expect(last_response.body.split(",").size).to eq(4)
    end

    it "lets client_limit: false switch it off for JSON" do
      get "/widgets.json", limit: 5, client: "off"

      expect(json["pagination"]["limit"]).to eq(2)
    end

    it "falls back to the call site's limit for a negative or junk page size" do
      get "/widgets.json", limit: -1
      expect(json["pagination"]["limit"]).to eq(2)

      get "/widgets.json", limit: "lots"
      expect(json["pagination"]["limit"]).to eq(2)
    end

    it "reads the configured limit_key" do
      StandardPagination.config.limit_key = "per_page"
      get "/widgets.json", per_page: 3, limit: 4

      expect(json["pagination"]["limit"]).to eq(3)
    end

    it "ignores a client-limit option left in Pagy::OPTIONS" do
      stub_const("Pagy::OPTIONS", Pagy::OPTIONS.merge(max_limit: 100, client_limit: 100))

      get "/widgets", limit: 5

      expect(last_response.body.split(",").size).to eq(2)
    end
  end

  describe ".rescue_pagination_errors" do
    it "redirects an out-of-range HTML page to the last page, keeping filters" do
      get "/widgets", page: 99, q: "x"

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with("/widgets?page=4&q=x")
      expect(last_request.env["rack.session"]["flash"]["flashes"]).to eq("notice" => "Showing the last page")
    end

    it "rebuilds the redirect from the route, so a crafted path stays on-site" do
      # A "//widgets?page=4" Location would be protocol-relative (host
      # "widgets"). Rails 8.1 already squeezes the path before the controller
      # sees it; this pins that the redirect stays on-site regardless.
      get "/widgets", { page: 99 }, { "PATH_INFO" => "//widgets" }

      expect(last_response.status).to eq(302)
      expect(URI(last_response.location).host).to eq("example.org")
      expect(URI(last_response.location).path).to eq("/widgets")
    end

    it "drops the page and limit params for any other bad option, so the redirect can't loop" do
      get "/widgets", size: -1, page: 2, limit: 5, q: "x"

      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with("/widgets?q=x&size=-1")
    end

    it "returns 400 with a null last_page for any other bad option in JSON" do
      get "/widgets.json", size: -1

      expect(last_response.status).to eq(400)
      expect(json).to eq("error" => "Invalid pagination parameters", "last_page" => nil)
    end

    it "returns 400 with last_page for JSON" do
      get "/widgets.json", page: 99

      expect(last_response.status).to eq(400)
      expect(json).to eq("error" => "Page out of range", "last_page" => 4)
    end

    it "wins over a catch-all declared before it" do
      get "/widgets.json", page: 99

      expect(last_response.body).not_to include("catch-all")
    end

    it "does not stack handlers when declared again in a subclass" do
      handlers = NotFoundWidgetsController.rescue_handlers.count { |handler| handler.first == "Pagy::OptionError" }

      expect(handlers).to eq(1)
    end

    it "responds 404 with html: :not_found" do
      get "/not_found_widgets", page: 99

      expect(last_response.status).to eq(404)
    end

    it "calls a named method with html: <method>" do
      get "/custom_widgets", page: 99

      expect(last_response.status).to eq(410)
      expect(last_response.body).to eq("custom: Pagy::RangeError")
    end
  end
end
