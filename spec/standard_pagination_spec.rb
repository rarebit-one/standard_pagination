require "spec_helper"

RSpec.describe StandardPagination do
  describe ".check_pagy_options!" do
    it "passes when Pagy::OPTIONS sets no client-limit option" do
      expect(described_class.check_pagy_options!({ limit: 10 })).to be_nil
    end

    it "raises on a leftover max_limit or client_limit" do
      expect { described_class.check_pagy_options!({ max_limit: 100 }) }
        .to raise_error(StandardPagination::ConfigurationError, /:max_limit/)
    end

    it "returns the message instead of raising when not strict" do
      expect(described_class.check_pagy_options!({ client_limit: 50 }, raise_error: false)).to include(":client_limit")
    end
  end

  it "ships the data keys every consumer's PaginationMetadata type expects" do
    expect(described_class::DATA_KEYS).to eq(%i[page pages count limit from to previous next])
  end
end
