require "test_helper"

# rules.md §4 : répartition des rôles, équité des pilotages, rotation du maître du jeu.
class RoleDistributorTest < ActiveSupport::TestCase
  def simulate(players_count, cups, rotate: true, random: seeded_random)
    ring = (1..players_count).to_a
    counts = Hash.new(0)
    plans = Array.new(cups) do |index|
      plan = RoleDistributor.call(ring: ring, rotate: rotate, cups_count: cups, cup_index: index,
                                  pilot_counts: counts.dup, random: random)
      plan.pairs.each { |pilot, _judge| counts[pilot] += 1 }
      plan
    end
    [ plans, ring.index_with { |player| counts[player] } ]
  end

  test "répartition des rôles selon le nombre de joueurs" do
    expected = { 4 => [ 2, 2 ], 5 => [ 2, 2 ], 6 => [ 3, 3 ], 7 => [ 3, 3 ], 8 => [ 4, 4 ], 9 => [ 4, 4 ] }

    expected.each do |count, (pilots, judges)|
      plan = simulate(count, 1).first.first

      assert_equal pilots, plan.pairs.size, "#{count} joueurs : pilotes"
      assert_equal judges, plan.pairs.map(&:last).size, "#{count} joueurs : juges"
    end
  end

  test "nombre pair : le MJ est l'un des juges ; nombre impair : le MJ ne joue pas" do
    (4..9).each do |count|
      plan = simulate(count, 1).first.first
      judges = plan.pairs.map(&:last)

      assert_equal count.even?, judges.include?(plan.game_master), "#{count} joueurs"
      assert_not_includes plan.pairs.map(&:first), plan.game_master
    end
  end

  test "chaque joueur a exactement un rôle par coupe" do
    (4..9).each do |count|
      with_seeds(20) do |random, seed|
        simulate(count, 6, random: random).first.each do |plan|
          pilots = plan.pairs.map(&:first)
          judges = plan.pairs.map(&:last)
          participants = pilots + judges
          participants << plan.game_master if count.odd?

          assert_equal (1..count).to_a, participants.sort, "#{count} joueurs, graine #{seed}"
          assert_equal participants.uniq, participants
        end
      end
    end
  end

  test "équité : pilotages identiques sur un cycle complet, écart d'au plus 1 sinon" do
    (4..9).each do |count|
      calculator = CupCountCalculator.new(count)

      (CupCountCalculator::DEFAULT..CupCountCalculator::MAX).each do |cups|
        with_seeds(15) do |random, seed|
          _plans, counts = simulate(count, cups, random: random)
          gap = counts.values.max - counts.values.min

          assert_operator gap, :<=, calculator.fairness_gap(cups), "#{count} joueurs, #{cups} coupes, graine #{seed} : #{counts}"
        end
      end
    end
  end

  test "rotation : chaque joueur est MJ une fois avant que l'un d'eux repasse, l'hôte ouvre" do
    (4..9).each do |count|
      plans, _counts = simulate(count, count * 2)
      masters = plans.map(&:game_master)

      assert_equal 1, masters.first
      assert_equal (1..count).to_a, masters.first(count).sort
      assert_equal masters.first(count), masters.last(count)
    end
  end

  test "sans rotation, l'hôte est toujours MJ" do
    plans, _counts = simulate(6, 4, rotate: false)

    assert_equal [ 1 ], plans.map(&:game_master).uniq
  end

  test "sans rotation et nombre impair, l'hôte ne pilote jamais mais les autres pilotent à égalité" do
    _plans, counts = simulate(5, 4, rotate: false)

    assert_equal 0, counts[1]
    assert_equal [ 2 ], counts.except(1).values.uniq
  end

  test "à graine égale le tirage est identique" do
    assert_equal simulate(7, 4, random: seeded_random(5)).first, simulate(7, 4, random: seeded_random(5)).first
  end

  test "les duos varient selon la graine" do
    results = Array.new(10) { |seed| simulate(9, 1, random: Random.new(seed)).first.first.pairs }

    assert_operator results.uniq.size, :>, 1
  end
end
