require "test_helper"

class GameMasterRotationTest < ActiveSupport::TestCase
  RING = %w[hôte b c d].freeze

  test "avec rotation, le MJ suit l'anneau puis recommence" do
    masters = Array.new(6) { |index| GameMasterRotation.call(ring: RING, rotate: true, cup_index: index) }

    assert_equal %w[hôte b c d hôte b], masters
  end

  test "sans rotation, le MJ est toujours l'hôte" do
    masters = Array.new(6) { |index| GameMasterRotation.call(ring: RING, rotate: false, cup_index: index) }

    assert_equal [ "hôte" ], masters.uniq
  end
end
