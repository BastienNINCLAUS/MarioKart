require "test_helper"

# rules.md §6 : tirages, lancement de coupe, course, validation par le MJ, points, enchaînement.
class RaceTest < ActiveSupport::TestCase
  setup do
    load_catalog
    @game = build_game(players: 6, started: true, cups_count: 2)
    @cup = start_current_cup(@game)
    @race = @cup.current_race
    @master = @cup.game_master
    @first, @second, @third = @cup.duos.to_a
  end

  test "le lancement de la coupe tire un fil rouge et une action spéciale distincts par duo" do
    assert @cup.in_progress?
    assert_equal 3, @cup.duos.map(&:fil_rouge_item).uniq.size
    assert_equal 3, @cup.duos.map(&:special_action_item).uniq.size
    assert @cup.duos.all? { |duo| duo.fil_rouge_item.fil_rouge? && duo.special_action_item.special_action? }
  end

  test "la première course est prête avec complication, et 3 tâches par duo dont une secrète tirée sans doublon" do
    assert_equal 1, @race.position
    assert @race.pending?
    assert_predicate @race.complication_item, :complication?
    assert_equal 9, @race.checks.size
    secrets = @race.checks.select(&:secret_task?)
    assert_equal 3, secrets.map(&:catalog_item).uniq.size
    assert_equal @cup.duos.map(&:id).sort, secrets.map(&:duo_id).sort
  end

  test "une complication ciblée désigne 2 duos de la coupe, les autres aucun" do
    with_seeds(30) do |random|
      game = build_game(players: 6, started: true, random: random)
      cup = start_current_cup(game, random: random)
      race = cup.current_race
      targeted = race.complication_item.params["type"] == "targeted"

      assert_equal targeted ? 2 : 0, race.target_duo_ids.size
      assert_empty race.target_duo_ids - cup.duos.map(&:id)
    end
  end

  test "la coupe exige le MJ, l'état préparation et tous les personnages" do
    game = build_game(players: 4, started: true)
    cup = game.current_cup

    assert_equal :characters_missing, assert_raises(FlowError) { cup.start!(by: cup.game_master) }.reason
    cup.duos.each_with_index { |duo, index| duo.update!(character: Characters::ALL[index]) }
    assert_equal :not_game_master, assert_raises(FlowError) { cup.start!(by: cup.duos.first.pilot) }.reason
    cup.start!(by: cup.game_master)
    assert_equal :not_setup, assert_raises(FlowError) { cup.start!(by: cup.game_master) }.reason
  end

  test "les 4 courses d'une coupe ont des complications toutes différentes" do
    complications = [ @race.complication_item ]
    3.times { complications << finish_current_race(@game).cup.current_race.complication_item }

    assert_equal 4, complications.uniq.size
  end

  test "seul le MJ lance la course, une seule fois" do
    assert_equal :not_game_master, assert_raises(FlowError) { @race.start!(by: @first.judge == @master ? @first.pilot : @first.judge) }.reason
    @race.start!(by: @master)
    assert @race.reload.running?
    assert_equal :not_pending, assert_raises(FlowError) { @race.start!(by: @master) }.reason
  end

  test "la course se termine avec positions, points de position et enchaîne sur la course suivante" do
    finish_current_race(@game, order: [ @third, @first, @second ])

    assert @race.reload.finished?
    assert_equal({ @third.id => 1, @first.id => 2, @second.id => 3 }, @race.race_results.to_h { |result| [ result.duo_id, result.position ] })
    assert_equal 2, @cup.reload.races.size
    assert @cup.current_race.pending?
    assert_equal 2, @cup.current_race.position
  end

  test "le MJ doit donner une place différente à chaque duo" do
    @race.start!(by: @master)

    [ { @first.id => 1, @second.id => 1, @third.id => 2 }, { @first.id => 1, @second.id => 2 }, { @first.id => 1, @second.id => 2, @third.id => 4 },
      { @first.id => 1, @second.id => 2, @third.id => "x" } ].each do |positions|
      assert_equal :invalid_positions, assert_raises(FlowError) { @race.finish!(by: @master, positions: positions) }.reason
    end
    assert @race.reload.running?
  end

  test "la course ne peut être terminée que si elle est en cours, par le MJ" do
    positions = { @first.id => 1, @second.id => 2, @third.id => 3 }

    assert_equal :not_running, assert_raises(FlowError) { @race.finish!(by: @master, positions: positions) }.reason
    @race.start!(by: @master)
    other = @cup.duos.map(&:pilot).find { |pilot| pilot != @master }
    assert_equal :not_game_master, assert_raises(FlowError) { @race.finish!(by: other, positions: positions) }.reason
  end

  test "points de position : le premier marque le plus, le juge ne marque rien" do
    @race.update!(complication_item: CatalogItem.find_by!(key: "objet_unique"), target_duo_ids: [])
    finish_current_race(@game, order: [ @second, @first, @third ])
    totals = @race.reload.score_entries.group(:player_id).sum(:points)

    assert_equal 3, totals.size
    assert_empty(totals.keys & @cup.duos.map(&:judge_id))
    assert_equal [ 6, 4, 2 ], [ totals[@second.pilot_id], totals[@first.pilot_id], totals[@third.pilot_id] ]
  end

  test "une tâche cochée et validée rapporte les points de son élément, une tâche refusée rien" do
    checks = @race.checks.select { |check| check.duo_id == @first.id }
    fil_rouge = checks.find(&:fil_rouge?)
    secret = checks.find(&:secret_task?)

    finish_current_race(@game, tick: [ fil_rouge, secret ], rejected: [ secret ])

    entries = @race.reload.score_entries.where(player: @first.pilot).index_by(&:kind)
    assert_equal fil_rouge.points, entries["fil_rouge"].points
    assert_equal fil_rouge, entries["fil_rouge"].check
    assert_nil entries["secret_task"]
    assert fil_rouge.reload.decision_validated?
    assert secret.reload.decision_rejected?
    assert secret.achieved?
  end

  test "une tâche non cochée reste en attente et ne rapporte rien" do
    finish_current_race(@game)

    assert @race.checks.reload.all?(&:decision_pending?)
    assert_empty @race.score_entries.where.not(kind: "position")
  end

  test "annuler les points de position est possible pour une complication manuelle" do
    @race.update!(complication_item: CatalogItem.find_by!(key: "pas_d_objets_offensifs"), target_duo_ids: [])
    finish_current_race(@game, cancelled: [ @first ])

    assert @race.race_results.find_by(duo: @first).position_points_cancelled
    assert_equal 0, @race.score_entries.find_by(player: @first.pilot, kind: "position").points
    assert_not @race.race_results.find_by(duo: @second).position_points_cancelled
  end

  test "annuler les points de position est refusé pour une complication automatique" do
    @race.update!(complication_item: CatalogItem.find_by!(key: "dernier_couronne"), target_duo_ids: [])
    @race.start!(by: @master)
    positions = { @first.id => 1, @second.id => 2, @third.id => 3 }

    error = assert_raises(FlowError) { @race.finish!(by: @master, positions: positions, cancelled_duo_ids: [ @first.id ]) }
    assert_equal :cancellation_not_allowed, error.reason
  end

  test "la complication secrète n'est visible que du MJ et des duos concernés" do
    secret = CatalogItem.find_by!(key: "les_rivaux")
    @race.update!(complication_item: secret, target_duo_ids: [ @first.id, @second.id ])

    assert @race.complication_visible_to?(@master)
    assert @race.complication_visible_to?(@first.pilot)
    assert @race.complication_visible_to?(@second.judge)
    outsider = @third.pilot == @master ? @third.judge : @third.pilot
    assert_not @race.complication_visible_to?(outsider)
  end

  test "une complication publique est visible de tous" do
    @race.update!(complication_item: CatalogItem.find_by!(key: "podium_inverse"), target_duo_ids: [])

    assert @cup.duos.flat_map { |duo| [ duo.pilot, duo.judge ] }.all? { |player| @race.complication_visible_to?(player) }
  end
end
