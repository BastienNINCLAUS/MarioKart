require "test_helper"

# rules.md §4 : cycle réduit par défaut, le MJ peut augmenter le nombre de coupes.
class CupCountCalculatorTest < ActiveSupport::TestCase
  test "le cycle réduit par défaut est de 2 coupes pour tous les effectifs" do
    (4..9).each { |count| assert_equal 2, CupCountCalculator.new(count).default }
  end

  test "cycle complet : 2 coupes si pair, autant de coupes que de joueurs si impair" do
    { 4 => 2, 5 => 5, 6 => 2, 7 => 7, 8 => 2, 9 => 9 }.each do |count, cycle|
      assert_equal cycle, CupCountCalculator.new(count).full_cycle, "#{count} joueurs"
    end
  end

  test "écart d'équité nul sur un cycle complet et de 1 sinon" do
    even = CupCountCalculator.new(6)
    odd = CupCountCalculator.new(5)

    assert_equal 0, even.fairness_gap(2)
    assert_equal 0, even.fairness_gap(4)
    assert_equal 1, even.fairness_gap(3)
    assert_equal 1, odd.fairness_gap(2)
    assert_equal 0, odd.fairness_gap(5)
    assert_equal 0, odd.fairness_gap(10)
  end

  test "le nombre de coupes valide va de 2 à 12" do
    calculator = CupCountCalculator.new(5)

    assert calculator.valid?(2)
    assert calculator.valid?(12)
    assert_not calculator.valid?(1)
    assert_not calculator.valid?(13)
    assert_not calculator.valid?(nil)
    assert_not calculator.valid?("3")
  end
end
