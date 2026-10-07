require "test_helper"

# rules.md §6, §9 : contestation, décision du MJ, vote, abandon et reprise d'un siège par un nouveau joueur.
class DisputesFlowTest < ActionDispatch::IntegrationTest
  setup do
    load_catalog
    @game = build_game(players: 6, started: true, cups_count: 2)
    @cup = start_current_cup(@game)
    @master = @cup.game_master
    @duo = @cup.duos.find { |duo| duo.judge != @master }
    race = @cup.current_race
    race.update!(complication_item: CatalogItem.find_by!(key: "objet_unique"), target_duo_ids: [])
    @check = race.checks.find { |check| check.duo_id == @duo.id && check.fil_rouge? }
    finish_current_race(@game, tick: [ @check ], rejected: [ @check ])
    @voters = @game.players.where.not(id: [ @duo.pilot_id, @duo.judge_id, @master.id ]).to_a
  end

  def open_dispute
    sign_in_as(@duo.pilot)
    post contest_game_check_path(@game, @check)
    @check.reload.dispute
  end

  test "le duo voit sa tâche refusée avec un bouton pour la contester, pas les autres" do
    sign_in_as(@duo.judge)
    get game_path(@game)
    assert_select "#disputes .contestable form[action='#{contest_game_check_path(@game, @check)}']"

    sign_in_as(@voters.first)
    get game_path(@game)
    assert_select "#disputes", false
  end

  test "le duo conteste : la tâche devient visible de tous et la contestation apparaît" do
    dispute = open_dispute

    assert_redirected_to game_path(@game)
    assert_equal "open", dispute.status

    sign_in_as(@voters.first)
    get game_path(@game)
    assert_select ".dispute[data-status=open]", 1
    assert_includes response.body, CGI.escapeHTML(@check.catalog_item.description)
    assert_select ".dispute form", false
  end

  test "un autre joueur ne peut pas contester" do
    sign_in_as(@voters.first)

    post contest_game_check_path(@game, @check)

    assert_equal I18n.t("flow_errors.not_duo_member"), flash[:alert]
    assert_nil @check.reload.dispute
  end

  test "contester deux fois est refusé" do
    open_dispute
    post contest_game_check_path(@game, @check)

    assert_equal I18n.t("flow_errors.not_contestable"), flash[:alert]
    assert_equal 1, Dispute.count
  end

  test "le MJ valide la tâche depuis la page" do
    dispute = open_dispute
    sign_in_as(@master)
    get game_path(@game)
    assert_select ".dispute form[action='#{decide_game_dispute_path(@game, dispute)}']", 2
    assert_select ".dispute form[action='#{start_vote_game_dispute_path(@game, dispute)}']"

    post decide_game_dispute_path(@game, dispute), params: { approve: true }

    assert dispute.reload.validated?
    assert @check.reload.decision_validated?
  end

  test "un joueur non autorisé ne tranche pas" do
    dispute = open_dispute
    sign_in_as(@voters.first)

    post decide_game_dispute_path(@game, dispute), params: { approve: true }

    assert_equal I18n.t("flow_errors.not_authority"), flash[:alert]
    assert dispute.reload.status_open?
  end

  test "vote complet : le MJ lance, les votants votent, la majorité décide" do
    dispute = open_dispute
    sign_in_as(@master)
    post start_vote_game_dispute_path(@game, dispute)
    assert dispute.reload.status_voting?

    @voters.each_with_index do |voter, index|
      sign_in_as(voter)
      get game_path(@game)
      assert_select ".dispute form[action='#{vote_game_dispute_path(@game, dispute)}']", 2
      post vote_game_dispute_path(@game, dispute), params: { approve: index < 2 }
    end

    assert dispute.reload.validated?
    assert @check.reload.decision_validated?
  end

  test "pendant le vote, le duo concerné et le MJ ne voient pas de bouton de vote" do
    dispute = open_dispute
    dispute.start_vote!(by: @master)

    [ @duo.pilot, @duo.judge, @master ].each do |player|
      sign_in_as(player)
      get game_path(@game)
      assert_select ".dispute form[action='#{vote_game_dispute_path(@game, dispute)}']", false
    end
  end

  test "un vote refusé affiche un message" do
    dispute = open_dispute
    dispute.start_vote!(by: @master)
    sign_in_as(@duo.pilot)

    post vote_game_dispute_path(@game, dispute), params: { approve: true }

    assert_equal I18n.t("flow_errors.not_voter"), flash[:alert]
  end

  test "égalité : le MJ voit les boutons pour trancher" do
    dispute = open_dispute
    dispute.start_vote!(by: @master)
    dispute.vote!(by: @voters[0], approve: true)
    dispute.vote!(by: @voters[1], approve: false)
    sign_in_as(@master)
    post close_vote_game_dispute_path(@game, dispute)
    assert dispute.reload.status_tied?

    get game_path(@game)
    assert_select ".dispute[data-status=tied] form[action='#{decide_game_dispute_path(@game, dispute)}']", 2
  end

  test "un non-membre ne peut rien faire sur une contestation" do
    dispute = open_dispute
    reset!

    post decide_game_dispute_path(@game, dispute), params: { approve: true }

    assert_redirected_to root_path(code: @game.code)
    assert dispute.reload.status_open?
  end

  test "les contestations d'une autre partie sont introuvables" do
    dispute = open_dispute
    other = build_game
    sign_in_as(other.host)

    post decide_game_dispute_path(other, dispute), params: { approve: true }

    assert_response :not_found
  end
end
