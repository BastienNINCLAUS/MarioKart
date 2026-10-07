# Invariants qui doivent tenir pour n'importe quelle partie terminée, quel que soit le déroulement.
module GameInvariants
  # extra_gap : écart d'équité toléré en plus, car chaque échange du MJ peut décaler 2 joueurs d'un pilotage.
  def assert_game_invariants(game, extra_gap: 0)
    game.reload
    assert game.finished?, "la partie doit être terminée"
    cups = game.cups.to_a
    seats = game.seats
    assert_equal game.cups_count, cups.size

    cups.each_with_index do |cup, index|
      assert cup.finished?
      assert cup.roles_valid?, "coupe #{cup.position} : rôles invalides"
      assert_equal Cup::RACES_COUNT, cup.races.size
      assert cup.races.all?(&:finished?)
      master_seat = seats[game.rotate_game_master ? index % seats.size : 0]
      assert_includes master_seat.map(&:id), cup.game_master_id, "coupe #{cup.position} : mauvais MJ"
      cup.races.each { |race| assert_race_invariants(race, cup) }
    end

    assert_fair_pilot_counts(game, seats, cups, extra_gap)
    assert_consistent_ranking(game)
  end

  def assert_race_invariants(race, cup)
    results = race.race_results.to_a
    assert_equal cup.duos.size, results.size
    assert_equal (1..results.size).to_a, results.map(&:position).sort
    pilot_ids = results.map(&:pilot_id)
    assert_equal pilot_ids.uniq, pilot_ids

    entries = race.score_entries.includes(:check).to_a
    assert_empty entries.map(&:player_id) - pilot_ids, "seuls les pilotes marquent des points"
    assert_equal results.size, entries.count { |entry| entry.kind == "position" }
    pilot_by_duo = results.to_h { |result| [ result.duo_id, result.pilot_id ] }
    entries.select(&:check).each do |entry|
      assert entry.check.counts?, "une tâche non validée rapporte des points"
      assert_equal entry.check.points, entry.points
      assert_equal pilot_by_duo.fetch(entry.check.duo_id), entry.player_id
    end
    race.checks.select(&:counts?).each { |check| assert(entries.any? { |entry| entry.check_id == check.id }, "tâche validée sans points") }

    snapshot = entries.map { |entry| [ entry.player_id, entry.kind, entry.points ] }.sort
    RaceScorer.call(race)
    assert_equal snapshot, race.score_entries.reload.map { |entry| [ entry.player_id, entry.kind, entry.points ] }.sort, "le recalcul doit être idempotent"
  end

  def assert_fair_pilot_counts(game, seats, cups, extra_gap)
    counts = seats.map { |chain| Duo.where(pilot_id: chain.map(&:id), cup_id: cups.map(&:id)).count }
    gap = CupCountCalculator.new(seats.size).fairness_gap(cups.size) + extra_gap

    assert_operator counts.max - counts.min, :<=, gap, "équité des pilotages : #{counts}"
  end

  def assert_consistent_ranking(game)
    ranking = game.ranking
    totals = ScoreEntry.where(game_id: game.id).group(:player_id).sum(:points)

    ranking.each { |entry| assert_equal totals.fetch(entry.player, 0), entry.points }
    assert_equal ranking.map(&:points).sort.reverse, ranking.map(&:points)
    assert_equal 1, ranking.first.rank
    assert_equal game.players.count, ranking.size
  end
end
