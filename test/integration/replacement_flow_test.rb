require "test_helper"

class ReplacementFlowTest < ActionDispatch::IntegrationTest
  setup do
    load_catalog
    @game = build_game(players: 6, started: true, cups_count: 2)
    @cup = start_current_cup(@game)
    @master = @cup.game_master
    @leaver = @cup.duos.find { |duo| duo.judge != @master }.pilot
  end

  test "le MJ voit un bouton d'abandon par joueur, un simple joueur non" do
    sign_in_as(@master)
    get game_path(@game)
    assert_select "#players_admin form[action='#{abandon_game_player_path(@game, @leaver)}']"
    assert_select "#players_admin form[action='#{abandon_game_player_path(@game, @game.host)}']", false

    sign_in_as(@leaver)
    get game_path(@game)
    assert_select "#players_admin", false
  end

  test "le MJ déclare l'abandon, un siège libre est annoncé à tous" do
    sign_in_as(@master)
    post abandon_game_player_path(@game, @leaver)

    assert @leaver.reload.abandoned?
    sign_in_as(@cup.duos.last.judge)
    get game_path(@game)
    assert_select ".open-seat", text: /#{@leaver.nickname}.*#{@game.code}/m
  end

  test "un simple joueur ne peut pas déclarer un abandon" do
    sign_in_as(@cup.duos.map(&:pilot).find { |pilot| pilot != @leaver })

    post abandon_game_player_path(@game, @leaver)

    assert_equal I18n.t("flow_errors.not_authority"), flash[:alert]
    assert @leaver.reload.connected?
  end

  test "le MJ réintègre un joueur revenu" do
    ReplacementService.abandon!(game: @game, by: @master, player: @leaver)
    sign_in_as(@master)

    post reinstate_game_player_path(@game, @leaver)

    assert @leaver.reload.connected?
  end

  test "une nouvelle personne rejoint avec le code et prend le siège libre" do
    ReplacementService.abandon!(game: @game, by: @master, player: @leaver)

    assert_difference "@game.players.count", 1 do
      post joins_path, params: { code: @game.code, nickname: "Relève" }
    end

    assert_redirected_to game_path(@game)
    replacement = @game.players.find_by!(nickname: "Relève")
    assert_equal @leaver, replacement.replaces
    follow_redirect!
    assert_response :success
    assert Duo.exists?(cup: @cup, pilot: replacement)
    assert_not Duo.exists?(cup: @cup, pilot: @leaver)
  end

  test "sans siège libre, rejoindre une partie lancée reste refusé" do
    assert_no_difference "@game.players.count" do
      post joins_path, params: { code: @game.code, nickname: "Curieux" }
    end

    assert_response :unprocessable_content
  end

  test "un pseudo déjà pris est refusé même quand un siège est libre" do
    ReplacementService.abandon!(game: @game, by: @master, player: @leaver)

    assert_no_difference "@game.players.count" do
      post joins_path, params: { code: @game.code, nickname: "joueur 3" }
    end

    assert_response :unprocessable_content
    assert_equal 1, @game.open_seats.count
  end

  test "le classement indique le joueur ayant abandonné" do
    ReplacementService.abandon!(game: @game, by: @master, player: @leaver)
    sign_in_as(@master)

    get game_path(@game)

    assert_select "#ranking li", text: /#{@leaver.nickname} \(#{I18n.t('games.ranking.abandoned')}\)/
  end
end
