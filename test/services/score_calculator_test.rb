require "test_helper"

# rules.md §7, §8 : points de position (provisoires), tâches validées, annulations, juge à 0.
class ScoreCalculatorTest < ActiveSupport::TestCase
  POSITIONS = { 10 => 1, 20 => 2, 30 => 3, 40 => 4 }.freeze

  def calculate(key: "pas_d_objets_offensifs", targets: [], cancelled: [], achievements: {}, positions: POSITIONS)
    ScoreCalculator.call(positions: positions, complication_key: key, targets: targets, cancelled: cancelled, achievements: achievements)
  end

  test "les points de position décroissent avec la place selon le nombre de duos" do
    assert_equal({ 1 => 8, 2 => 6, 3 => 4, 4 => 2 }, ScoreCalculator.position_points(4))
    assert_equal({ 1 => 4, 2 => 2 }, ScoreCalculator.position_points(2))
  end

  test "sans tâche, un duo marque ses points de position" do
    result = calculate

    assert_equal [ 8, 6, 4, 2 ], result.values.map(&:position)
    assert_equal [ 8, 6, 4, 2 ], result.values.map(&:total)
  end

  test "les tâches validées s'ajoutent par type" do
    result = calculate(achievements: { 20 => { "fil_rouge" => 3, "secret_task" => 5, "special_action" => 2 } })

    assert_equal 3, result[20].fil_rouge
    assert_equal 5, result[20].secret_task
    assert_equal 2, result[20].special_action
    assert_equal 6 + 3 + 5 + 2, result[20].total
    assert_equal 0, result[10].fil_rouge
  end

  test "les points de position annulés par le MJ tombent à zéro mais pas ceux des tâches" do
    result = calculate(cancelled: [ 10 ], achievements: { 10 => { "fil_rouge" => 3 } })

    assert_equal 0, result[10].position
    assert_equal 3, result[10].total
    assert_equal 6, result[20].position
  end

  test "la complication s'applique avant les tâches" do
    result = calculate(key: "dernier_couronne", achievements: { 40 => { "secret_task" => 5 } })

    assert_equal 4, result[40].position
    assert_equal 9, result[40].total
  end

  test "une complication ciblée utilise les duos tirés" do
    result = calculate(key: "les_amoureux", targets: [ 10, 40 ])

    assert_equal [ 0, 6, 4, 0 ], result.values.map(&:position)
  end
end
