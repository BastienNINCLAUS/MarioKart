require "test_helper"

# Parties complètes : enchaînement courses -> coupes -> fin de partie, points cumulés et classement.
class GameFlowTest < ActiveSupport::TestCase
  setup { load_catalog }

  test "terminer la 4e course termine la coupe et prépare la suivante avec un autre MJ" do
    game = build_game(players: 4, started: true, cups_count: 2)
    first_cup = start_current_cup(game)
    Cup::RACES_COUNT.times { finish_current_race(game) }

    assert first_cup.reload.finished?
    assert_equal 4, first_cup.races.count
    assert game.reload.in_progress?
    second = game.current_cup
    assert_equal 2, second.position
    assert second.setup?
    assert_not_equal first_cup.game_master, second.game_master
    assert second.roles_valid?
  end

  test "terminer la dernière coupe termine la partie" do
    game = play_whole_game(build_game(players: 4, started: true, cups_count: 2))

    assert game.finished?
    assert_equal 2, game.cups.count
    assert game.cups.all?(&:finished?)
    assert_equal 8, Race.joins(:cup).where(cups: { game_id: game.id }).finished.count
  end

  test "parties complètes de 4 à 9 joueurs : rôles valides, équité, points, un seul vainqueur au moins" do
    (4..9).each do |count|
      cycle = CupCountCalculator.new(count).full_cycle
      game = play_whole_game(build_game(players: count, started: true, cups_count: [ cycle, 2 ].max, random: seeded_random(count)), random: seeded_random(count))

      assert game.finished?, "#{count} joueurs"
      assert game.cups.all?(&:roles_valid?), "#{count} joueurs : rôles"
      pilot_counts = Duo.joins(:cup).where(cups: { game_id: game.id }).group(:pilot_id).count
      assert_equal count, pilot_counts.size
      assert_equal 1, pilot_counts.values.uniq.size, "#{count} joueurs : équité #{pilot_counts}"

      ranking = game.ranking
      assert_equal count, ranking.size
      assert_equal 1, ranking.first.rank
      assert_equal ranking.map(&:points).sort.reverse, ranking.map(&:points)
    end
  end

  test "le juge ne marque aucun point : un joueur qui n'a jamais piloté a 0" do
    game = build_game(players: 5, started: true, cups_count: 2)
    start_current_cup(game)
    Cup::RACES_COUNT.times { finish_current_race(game) }
    cup = game.cups.first
    non_pilots = game.players.where.not(id: cup.duos.map(&:pilot_id))

    assert non_pilots.any?
    assert(non_pilots.all? { |player| ScoreEntry.where(player: player).sum(:points).zero? })
  end

  test "les points s'accumulent sur toute la partie" do
    game = build_game(players: 4, started: true, cups_count: 2)
    cup = start_current_cup(game)
    pilot = cup.duos.first.pilot
    Cup::RACES_COUNT.times { finish_current_race(game, order: cup.duos.to_a) }

    entries = ScoreEntry.where(player: pilot)
    assert_equal 4, entries.where(kind: "position").count
    assert_equal entries.sum(:points), game.ranking.find { |entry| entry.player == pilot.id }.points
  end

  test "départage : à égalité de points, le joueur avec le plus d'actions spéciales est devant" do
    game = build_game(players: 4, started: true, cups_count: 2)
    cup = start_current_cup(game)
    first, second = cup.duos.to_a
    neutral = CatalogItem.find_by!(key: "objet_unique")
    play = lambda do |order, tick: []|
      game.current_cup.current_race.update!(complication_item: neutral, target_duo_ids: [])
      finish_current_race(game, order: order, tick: tick)
    end

    special = cup.current_race.checks.find { |check| check.duo_id == first.id && check.special_action? }
    play.call([ first, second ], tick: [ special ])
    2.times { play.call([ second, first ]) }
    ranking = game.ranking.index_by(&:player)

    assert_equal 10, ranking[first.pilot_id].points
    assert_equal 10, ranking[second.pilot_id].points
    assert_equal 1, ranking[first.pilot_id].special_actions
    assert_equal [ 1, 2 ], [ ranking[first.pilot_id].rank, ranking[second.pilot_id].rank ]
  end
end
