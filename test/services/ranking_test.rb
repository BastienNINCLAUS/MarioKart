require "test_helper"

# rules.md §8 : classement individuel et départage (actions spéciales, tâches secrètes, classement de coupe).
class RankingTest < ActiveSupport::TestCase
  def rank(points: {}, special: {}, secret: {}, cups: {}, players: %i[a b c d])
    Ranking.call(players: players, points: points, special_actions: special, secret_tasks: secret, cup_points: cups)
  end

  def ranks(entries)
    entries.to_h { |entry| [ entry.player, entry.rank ] }
  end

  test "le classement suit les points décroissants" do
    entries = rank(points: { a: 5, b: 12, c: 9, d: 0 })

    assert_equal %i[b c a d], entries.map(&:player)
    assert_equal({ b: 1, c: 2, a: 3, d: 4 }, ranks(entries))
  end

  test "un joueur sans point est classé avec 0" do
    assert_equal 0, rank(points: { a: 3 }).find { |entry| entry.player == :b }.points
  end

  test "à égalité de points, le plus d'actions spéciales passe devant" do
    entries = rank(points: { a: 10, b: 10 }, special: { a: 1, b: 3 })

    assert_equal({ b: 1, a: 2, c: 3, d: 3 }, ranks(entries))
  end

  test "puis le plus de tâches secrètes" do
    entries = rank(points: { a: 10, b: 10 }, special: { a: 2, b: 2 }, secret: { a: 4, b: 1 })

    assert_equal({ a: 1, b: 2, c: 3, d: 3 }, ranks(entries))
  end

  test "puis le meilleur classement de coupe, calculé en interne" do
    cups = { 1 => { a: 10, b: 4, c: 2, d: 0 }, 2 => { a: 0, b: 6, c: 8, d: 1 } }
    entries = rank(points: { a: 10, b: 10, c: 10, d: 1 }, cups: cups)

    # Rangs triés : c [1, 3] devant a [1, 4] devant b [2, 2] (on compare d'abord le meilleur rang).
    assert_equal [ 1, 3 ], entries.find { |entry| entry.player == :c }.cup_ranks
    assert_equal [ 1, 4 ], entries.find { |entry| entry.player == :a }.cup_ranks
    assert_equal %i[c a b d], entries.map(&:player)
  end

  test "une égalité parfaite partage le rang et le suivant est décalé" do
    entries = rank(points: { a: 10, b: 10, c: 4, d: 1 })

    assert_equal({ a: 1, b: 1, c: 3, d: 4 }, ranks(entries))
  end

  test "à égalité parfaite l'ordre d'arrivée des joueurs est conservé" do
    assert_equal %i[a b c d], rank.map(&:player)
    assert_equal %i[d c b a], rank(players: %i[d c b a]).map(&:player)
  end

  test "les rangs de coupe tiennent compte des égalités de points dans la coupe" do
    entries = rank(cups: { 1 => { a: 5, b: 5, c: 1, d: 0 } })

    assert_equal [ 1 ], entries.find { |entry| entry.player == :a }.cup_ranks
    assert_equal [ 1 ], entries.find { |entry| entry.player == :b }.cup_ranks
    assert_equal [ 3 ], entries.find { |entry| entry.player == :c }.cup_ranks
    assert_equal [ 4 ], entries.find { |entry| entry.player == :d }.cup_ranks
  end
end
