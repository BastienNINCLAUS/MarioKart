require "test_helper"

# rules.md §6 et §9 : contestation d'une décision du MJ, vote des autres joueurs, le MJ tranche.
class DisputeTest < ActiveSupport::TestCase
  setup do
    load_catalog
    @game = build_game(players: 6, started: true)
    @cup = start_current_cup(@game)
    @master = @cup.game_master
    @duo = @cup.duos.find { |duo| duo.judge != @master }
    race = @cup.current_race
    race.update!(complication_item: CatalogItem.find_by!(key: "objet_unique"), target_duo_ids: [])
    @check = race.checks.find { |check| check.duo_id == @duo.id && check.fil_rouge? }
    finish_current_race(@game, tick: [ @check ], rejected: [ @check ])
    @check.reload
    @voters = @game.players.where.not(id: [ @duo.pilot_id, @duo.judge_id, @master.id ]).to_a
  end

  def contest
    @check.contest!(by: @duo.pilot)
  end

  def score_of(player)
    ScoreEntry.where(player: player).sum(:points)
  end

  test "un membre du duo conteste une tâche cochée puis refusée" do
    dispute = contest

    assert dispute.status_open?
    assert @check.reload.contested?
    assert_equal @duo.pilot, dispute.opened_by
    assert_equal @check, dispute.check
  end

  test "le juge du duo peut aussi contester" do
    assert @check.contest!(by: @duo.judge).status_open?
  end

  test "un autre joueur ne peut pas contester" do
    assert_equal :not_duo_member, assert_raises(FlowError) { @check.contest!(by: @voters.first) }.reason
    assert_equal :not_duo_member, assert_raises(FlowError) { @check.contest!(by: nil) }.reason
  end

  test "seule une tâche cochée puis refusée se conteste, une seule fois" do
    contest
    assert_equal :not_contestable, assert_raises(FlowError) { @check.reload.contest!(by: @duo.pilot) }.reason

    other = @cup.races.first.checks.find { |check| check.duo_id == @duo.id && check.secret_task? }
    assert_equal :not_contestable, assert_raises(FlowError) { other.contest!(by: @duo.pilot) }.reason
  end

  test "la tâche contestée est dévoilée à tous les joueurs" do
    assert_not @check.visible_to?(@voters.first)

    contest

    assert @check.reload.visible_to?(@voters.first)
  end

  test "le MJ valide la tâche : décision, points et classement sont corrigés" do
    dispute = contest
    before = score_of(@duo.pilot)

    dispute.decide!(by: @master, approve: true)

    assert dispute.reload.status_resolved?
    assert dispute.validated?
    assert @check.reload.decision_validated?
    assert_equal before + @check.points, score_of(@duo.pilot)
    assert_equal @duo.pilot_id, ScoreEntry.find_by!(check: @check).player_id
    assert_equal score_of(@duo.pilot), @game.ranking.find { |entry| entry.player == @duo.pilot_id }.points
  end

  test "le MJ maintient le refus : rien ne change" do
    dispute = contest
    before = score_of(@duo.pilot)

    dispute.decide!(by: @master, approve: false)

    assert dispute.reload.status_resolved?
    assert_not dispute.validated?
    assert @check.reload.decision_rejected?
    assert_equal before, score_of(@duo.pilot)
  end

  test "l'hôte peut aussi trancher, pas un autre joueur" do
    dispute = contest

    assert_equal :not_authority, assert_raises(FlowError) { dispute.decide!(by: @voters.first, approve: true) }.reason
    assert_equal :not_authority, assert_raises(FlowError) { dispute.decide!(by: @duo.pilot, approve: true) }.reason
    dispute.decide!(by: @game.host, approve: true)

    assert dispute.reload.validated?
  end

  test "une contestation tranchée ne peut plus l'être" do
    dispute = contest
    dispute.decide!(by: @master, approve: false)

    assert_equal :not_decidable, assert_raises(FlowError) { dispute.decide!(by: @master, approve: true) }.reason
  end

  test "les votants sont tous les joueurs présents sauf le duo concerné et le MJ" do
    dispute = contest

    assert_equal @voters.sort_by(&:id), dispute.voters.to_a
    assert_equal 3, dispute.voters.count
  end

  test "un joueur qui a abandonné ne vote pas" do
    dispute = contest
    @voters.first.abandoned!

    assert_not_includes dispute.voters, @voters.first
  end

  test "le MJ lance un vote, une seule fois" do
    dispute = contest
    dispute.start_vote!(by: @master)

    assert dispute.status_voting?
    assert_equal :not_open, assert_raises(FlowError) { dispute.start_vote!(by: @master) }.reason
  end

  test "seule l'autorité lance le vote, et il faut des votants" do
    dispute = contest
    assert_equal :not_authority, assert_raises(FlowError) { dispute.start_vote!(by: @duo.pilot) }.reason

    @voters.each(&:abandoned!)
    assert_equal :no_voters, assert_raises(FlowError) { dispute.start_vote!(by: @master) }.reason
  end

  test "majorité pour : la tâche est validée quand tous ont voté" do
    dispute = contest
    dispute.start_vote!(by: @master)

    dispute.vote!(by: @voters[0], approve: true)
    assert dispute.reload.status_voting?
    dispute.vote!(by: @voters[1], approve: true)
    dispute.vote!(by: @voters[2], approve: false)

    assert dispute.reload.validated?
    assert @check.reload.decision_validated?
  end

  test "majorité contre : le refus est maintenu" do
    dispute = contest
    dispute.start_vote!(by: @master)

    dispute.vote!(by: @voters[0], approve: false)
    dispute.vote!(by: @voters[1], approve: false)
    dispute.vote!(by: @voters[2], approve: true)

    assert dispute.reload.status_resolved?
    assert_not dispute.validated?
    assert @check.reload.decision_rejected?
  end

  test "égalité : le MJ tranche" do
    dispute = contest
    dispute.start_vote!(by: @master)
    dispute.vote!(by: @voters[0], approve: true)
    dispute.vote!(by: @voters[1], approve: false)
    dispute.close_vote!(by: @master)

    assert dispute.reload.status_tied?
    dispute.decide!(by: @master, approve: true)
    assert dispute.reload.validated?
  end

  test "le MJ peut clore le vote avec les voix exprimées" do
    dispute = contest
    dispute.start_vote!(by: @master)
    dispute.vote!(by: @voters[0], approve: true)

    dispute.close_vote!(by: @master)

    assert dispute.reload.validated?
  end

  test "clore un vote sans voix donne une égalité" do
    dispute = contest
    dispute.start_vote!(by: @master)
    dispute.close_vote!(by: @master)

    assert dispute.reload.status_tied?
  end

  test "règles de vote : en cours, votant, une seule voix" do
    dispute = contest
    assert_equal :not_voting, assert_raises(FlowError) { dispute.vote!(by: @voters[0], approve: true) }.reason
    assert_equal :not_voting, assert_raises(FlowError) { dispute.close_vote!(by: @master) }.reason

    dispute.start_vote!(by: @master)
    [ @duo.pilot, @duo.judge, @master, nil ].each do |outsider|
      assert_equal :not_voter, assert_raises(FlowError) { dispute.vote!(by: outsider, approve: true) }.reason
    end
    dispute.vote!(by: @voters[0], approve: true)
    assert_equal :already_voted, assert_raises(FlowError) { dispute.vote!(by: @voters[0], approve: false) }.reason
    assert_equal :not_authority, assert_raises(FlowError) { dispute.close_vote!(by: @voters[0]) }.reason
  end

  test "on ne tranche pas pendant le vote" do
    dispute = contest
    dispute.start_vote!(by: @master)

    assert_equal :not_decidable, assert_raises(FlowError) { dispute.decide!(by: @master, approve: true) }.reason
  end

  test "valider une contestation sur une course passée ne touche pas aux autres points" do
    dispute = contest
    other_totals = ScoreEntry.where.not(player: @duo.pilot).group(:player_id).sum(:points)

    dispute.decide!(by: @master, approve: true)

    assert_equal other_totals, ScoreEntry.where.not(player: @duo.pilot).group(:player_id).sum(:points)
  end
end
