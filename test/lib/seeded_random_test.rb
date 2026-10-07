require "test_helper"

class SeededRandomTest < ActiveSupport::TestCase
  test "une même graine produit la même séquence" do
    assert_equal Array.new(5) { seeded_random(1).rand(100) }, Array.new(5) { seeded_random(1).rand(100) }
  end

  test "with_seeds itère sur le nombre de graines demandé" do
    seeds = []
    with_seeds(10) { |_random, seed| seeds << seed }

    assert_equal (0..9).to_a, seeds
  end
end
