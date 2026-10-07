require "test_helper"

# rules.md §13 : abandon décidé par le MJ, points conservés, remplacement par une personne disponible.
class ReplacementServiceTest < ActiveSupport::TestCase
  setup do
    load_catalog
    @game = build_game(players: 6, started: true, cups_count: 2)
    @cup = start_current_cup(@game)
    @master = @cup.game_master
    @pilot_duo = @cup.duos.find { |duo| duo.judge != @master }
    @leaver = @pilot_duo.pilot
  end

  def abandon(player = @leaver, by: @master)
    ReplacementService.abandon!(game: @game, by: by, player: player)
  end

  def fill(nickname = "Nouveau")
    ReplacementService.fill_seat!(game: @game, nickname: nickname)
  end

  test "le MJ marque un joueur comme ayant abandonné, l'hôte aussi" do
    abandon
    assert @leaver.reload.abandoned?

    other = @cup.duos.map(&:judge).find { |judge| judge != @master && judge != @game.host }
    abandon(other, by: @game.host)
    assert other.reload.abandoned?
  end

  test "un autre joueur ne peut pas décider d'un abandon" do
    other = @cup.duos.find { |duo| duo.pilot != @leaver && duo.pilot != @master }.pilot

    assert_equal :not_authority, assert_raises(FlowError) { abandon(@leaver, by: other) }.reason
    assert_equal :not_authority, assert_raises(FlowError) { abandon(@leaver, by: nil) }.reason
    assert @leaver.reload.connected?
  end

  test "l'hôte ne peut pas abandonner, un joueur ne peut pas abandonner deux fois" do
    assert_equal :cannot_abandon_host, assert_raises(FlowError) { abandon(@game.host) }.reason
    abandon
    assert_equal :already_abandoned, assert_raises(FlowError) { abandon }.reason
  end

  test "l'abandon n'est possible que pendant la partie" do
    lobby = build_game(players: 4)
    error = assert_raises(FlowError) { ReplacementService.abandon!(game: lobby, by: lobby.host, player: lobby.players.last) }

    assert_equal :not_in_progress, error.reason
  end

  test "le joueur qui revient avant remplacement est réintégré" do
    abandon
    ReplacementService.reinstate!(game: @game, by: @master, player: @leaver)

    assert @leaver.reload.connected?
    assert_empty @game.open_seats
  end

  test "on ne réintègre pas un joueur connecté ni déjà remplacé" do
    assert_equal :not_abandoned, assert_raises(FlowError) { ReplacementService.reinstate!(game: @game, by: @master, player: @leaver) }.reason

    abandon
    fill
    assert_equal :seat_taken, assert_raises(FlowError) { ReplacementService.reinstate!(game: @game, by: @master, player: @leaver) }.reason
  end

  test "un siège libre apparaît dès l'abandon" do
    assert_empty @game.open_seats
    abandon

    assert_equal [ @leaver ], @game.open_seats.to_a
  end

  test "le remplaçant prend la place du pilote dans la coupe en cours" do
    abandon
    replacement = fill

    assert_equal replacement, @pilot_duo.reload.pilot
    assert_equal @leaver, replacement.replaces
    assert @cup.reload.roles_valid?
    assert_empty @game.open_seats
  end

  test "le remplaçant peut reprendre la place d'un juge" do
    judge = @cup.duos.map(&:judge).find { |candidate| candidate != @master && candidate != @game.host }
    duo = @cup.duos.find { |candidate| candidate.judge == judge }
    abandon(judge)

    replacement = fill

    assert_equal replacement, duo.reload.judge
    assert @cup.reload.roles_valid?
  end

  test "l'abandon d'un MJ non hôte : l'hôte décide et le remplaçant devient MJ et juge de la coupe en préparation" do
    game = build_game(players: 6, started: true, cups_count: 4)
    start_current_cup(game)
    Cup::RACES_COUNT.times { finish_current_race(game) }
    cup = game.current_cup
    leaver = cup.game_master
    assert_not_equal game.host, leaver

    ReplacementService.abandon!(game: game, by: game.host, player: leaver)
    replacement = ReplacementService.fill_seat!(game: game, nickname: "Relève")

    assert_equal replacement, cup.reload.game_master
    assert cup.game_master_is_judge?
    assert cup.roles_valid?
  end

  test "le joueur ayant abandonné garde ses points et reste au classement" do
    finish_current_race(@game)
    points = ScoreEntry.where(player: @leaver).sum(:points)
    abandon
    replacement = fill

    ranking = @game.ranking.index_by(&:player)
    assert_equal points, ranking[@leaver.id].points
    assert_equal 0, ranking[replacement.id].points
    assert_equal 7, ranking.size
  end

  test "les points déjà gagnés restent à l'ancien pilote même si une contestation les recalcule" do
    race = @cup.current_race
    race.update!(complication_item: CatalogItem.find_by!(key: "objet_unique"), target_duo_ids: [])
    check = race.checks.find { |candidate| candidate.duo_id == @pilot_duo.id && candidate.fil_rouge? }
    finish_current_race(@game, tick: [ check ], rejected: [ check ])
    abandon
    replacement = fill

    check.reload.contest!(by: replacement).decide!(by: @master, approve: true)

    assert_equal @leaver.id, ScoreEntry.find_by!(check: check).player_id
    assert_equal 0, ScoreEntry.where(player: replacement).sum(:points)
  end

  test "sans siège libre, personne ne peut prendre la place" do
    assert_equal :no_open_seat, assert_raises(FlowError) { fill }.reason
  end

  test "un pseudo déjà pris est refusé et rien n'est modifié" do
    abandon

    assert_raises(ActiveRecord::RecordInvalid) { fill("joueur 2") }
    assert_equal [ @leaver ], @game.open_seats.to_a
  end

  test "les sièges gardent l'ordre de rotation et le remplaçant en hérite" do
    before = @game.rotation_order
    abandon
    replacement = fill

    after = @game.rotation_order
    assert_equal before.size, after.size
    assert_equal before.index(@leaver), after.index(replacement)
    assert_equal before - [ @leaver ], after - [ replacement ]
  end

  test "le remplaçant compte comme l'ancien pilote : il ne pilote pas deux coupes de suite" do
    abandon
    replacement = fill
    Cup::RACES_COUNT.times { finish_current_race(@game) }

    first_pilots = @cup.reload.duos.map(&:pilot)
    second_pilots = @game.current_cup.duos.map(&:pilot)
    assert_includes first_pilots, replacement
    assert_empty first_pilots & second_pilots
  end

  test "la coupe suivante est tirée avec les sièges actuels, le remplaçant tient la place de l'ancien" do
    abandon
    replacement = fill
    Cup::RACES_COUNT.times { finish_current_race(@game) }

    second = @game.current_cup
    participants = second.duos.flat_map { |duo| [ duo.pilot, duo.judge ] } + [ second.game_master ]
    assert_includes participants, replacement
    assert_not_includes participants, @leaver
    assert second.roles_valid?
  end

  test "à la fin, la partie avec remplacement se termine normalement" do
    abandon
    fill
    Cup::RACES_COUNT.times { finish_current_race(@game) }
    start_current_cup(@game)
    Cup::RACES_COUNT.times { finish_current_race(@game) }

    assert @game.reload.finished?
  end
end
