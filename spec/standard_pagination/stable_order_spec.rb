require "spec_helper"

RSpec.describe StandardPagination::StableOrder do
  def sql(relation) = described_class.apply(relation).to_sql

  it "appends the primary key in the direction of the last sort key" do
    expect(sql(Widget.order(rank: :desc))).to end_with(%(ORDER BY "widgets"."rank" DESC, "widgets"."id" DESC))
    expect(sql(Widget.order(:rank))).to end_with(%(ORDER BY "widgets"."rank" ASC, "widgets"."id" ASC))
  end

  it "reads the direction of a string sort key" do
    expect(sql(Widget.order("rank DESC"))).to end_with(%(ORDER BY rank DESC, "widgets"."id" DESC))
    expect(sql(Widget.order("name ASC, rank DESC"))).to end_with(%("widgets"."id" DESC))
  end

  it "orders an unordered relation by the primary key" do
    expect(sql(Widget.all)).to end_with(%(ORDER BY "widgets"."id" ASC))
  end

  it "leaves a relation already ordered by the primary key alone" do
    [ Widget.order(:id), Widget.order(rank: :desc, id: :asc), Widget.order("widgets.id DESC"), Widget.order("rank, id") ].each do |relation|
      expect(described_class.apply(relation)).to equal(relation)
    end
  end

  it "leaves relations it cannot safely extend alone" do
    [
      Widget.group(:category).order(:category),
      Widget.select(:category).distinct.order(:category),
      Widget.select("DISTINCT category").order(:category),
      Widget.from("widgets AS w")
    ].each do |relation|
      expect(described_class.apply(relation)).to equal(relation)
    end
  end

  it "passes non-relations through" do
    array = [ 3, 1, 2 ]
    expect(described_class.apply(array)).to equal(array)
  end

  describe "Model.stable_order" do
    it "orders within the current scope" do
      Widget.create!(name: "x", rank: 1, category: "a")
      Widget.create!(name: "y", rank: 1, category: "a")
      Widget.create!(name: "z", rank: 1, category: "b")

      expect(Widget.where(category: "a").stable_order(rank: :desc).map(&:name)).to eq(%w[y x])
    end
  end
end
