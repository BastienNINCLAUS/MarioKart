require "test_helper"

class CatalogDrawerTest < ActiveSupport::TestCase
  setup { load_catalog }

  test "tire le nombre demandé d'éléments distincts du bon type" do
    items = CatalogDrawer.call(kind: :secret_task, count: 4, random: seeded_random)

    assert_equal 4, items.size
    assert_equal items.uniq, items
    assert items.all?(&:secret_task?)
  end

  test "à graine égale le tirage est identique, et il varie selon la graine" do
    draw = ->(seed) { CatalogDrawer.call(kind: :fil_rouge, count: 3, random: Random.new(seed)).map(&:key) }

    assert_equal draw.call(1), draw.call(1)
    assert_operator Array.new(10) { |seed| draw.call(seed) }.uniq.size, :>, 1
  end

  test "les éléments exclus ne sont pas retirés tant qu'il en reste assez" do
    excluded = CatalogItem.complication.order(:id).first(5)

    with_seeds(20) do |random|
      assert_equal CatalogItem.complication.order(:id).last, CatalogDrawer.call(kind: :complication, count: 1, exclude: excluded, random: random).first
    end
  end

  test "l'exclusion est ignorée quand elle empêcherait de tirer assez d'éléments" do
    all = CatalogItem.complication.to_a

    assert_equal 1, CatalogDrawer.call(kind: :complication, count: 1, exclude: all, random: seeded_random).size
  end

  test "trop peu d'éléments dans le catalogue lève une erreur" do
    assert_raises(CatalogDrawer::NotEnoughItems) { CatalogDrawer.call(kind: :special_action, count: 6) }
  end
end
