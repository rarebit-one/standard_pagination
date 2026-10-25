require "spec_helper"

RSpec.describe StandardPagination::Mcp do
  before { %w[a b c d e].each { |name| Widget.create!(name:, rank: 1, category: name < "c" ? "low" : "high") } }

  it "returns records and the MCP metadata shape" do
    records, meta = described_class.paginate(Widget.order(:rank), page: 2, per_page: 2)

    expect(records.map(&:name)).to eq(%w[c d])
    expect(meta).to eq(page: 2, per_page: 2, total_count: 5, total_pages: 3)
  end

  it "clamps page and per_page" do
    _, meta = described_class.paginate(Widget.all, page: 0, per_page: 500)
    expect(meta).to include(page: 1, per_page: 100)

    _, meta = described_class.paginate(Widget.all, per_page: "junk")
    expect(meta[:per_page]).to eq(20)
  end

  it "returns no records past the last page" do
    records, meta = described_class.paginate(Widget.all, page: 9, per_page: 2)

    expect(records).to be_empty
    expect(meta[:total_pages]).to eq(3)
  end

  it "counts groups for a GROUP BY relation" do
    records, meta = described_class.paginate(Widget.group(:category).select(:category).order(:category), per_page: 1)

    expect(records.map(&:category)).to eq(%w[high])
    expect(meta).to include(total_count: 2, total_pages: 2)
  end

  it "counts the distinct rows for an inline DISTINCT projection" do
    records, meta = described_class.paginate(Widget.select("DISTINCT category").order(:category), per_page: 1)

    expect(records.map(&:category)).to eq(%w[high])
    expect(meta).to include(total_count: 2, total_pages: 2)
  end

  it "breaks ties unless tiebreak: false" do
    records, = described_class.paginate(Widget.order(rank: :desc), per_page: 5)
    expect(records.map(&:name)).to eq(%w[e d c b a])

    allow(StandardPagination::StableOrder).to receive(:apply).and_call_original
    described_class.paginate(Widget.order(rank: :desc), tiebreak: false)
    expect(StandardPagination::StableOrder).not_to have_received(:apply)
  end
end
