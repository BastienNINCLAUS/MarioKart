require "test_helper"

# Affichage mobile : bandeau de rôle, barre du code de partie, manifeste d'application.
class MobileUiTest < ActionDispatch::IntegrationTest
  setup { load_catalog }

  test "le manifeste décrit l'application installable" do
    get pwa_manifest_path(format: :json)

    assert_response :success
    manifest = response.parsed_body
    assert_equal "Mario Kart Party", manifest["name"]
    assert_equal "standalone", manifest["display"]
    assert_equal "fr", manifest["lang"]
  end

  test "la page déclare le manifeste, la couleur du thème et la largeur d'écran" do
    get root_path

    assert_select "link[rel=manifest]"
    assert_select "meta[name=theme-color]"
    assert_select "meta[name=viewport][content*='width=device-width']"
    assert_select "html[lang=fr]"
  end

  test "en partie, une barre fixe rappelle le code et le pseudo" do
    game = build_game(players: 4, started: true)
    sign_in_as(game.host)

    get game_path(game)

    assert_select ".sticky #game_code", game.code
    assert_select ".sticky", text: /#{game.host.nickname}/
  end

  test "le MJ juge d'un effectif pair le voit dans son bandeau" do
    game = build_game(players: 6, started: true)
    cup = game.current_cup
    sign_in_as(cup.game_master)

    get game_path(game)

    pilot = cup.duo_for(cup.game_master).pilot
    assert_select "#role", I18n.t("games.role.game_master_judge", pilot: pilot.nickname)
  end

  test "le MJ qui ne joue pas (effectif impair) le voit dans son bandeau" do
    game = build_game(players: 5, started: true)
    sign_in_as(game.current_cup.game_master)

    get game_path(game)

    assert_select "#role", I18n.t("games.role.game_master")
  end

  test "pilote et juge voient leur partenaire dans leur bandeau" do
    game = build_game(players: 4, started: true)
    duo = game.current_cup.duos.find { |candidate| candidate.judge != game.current_cup.game_master }

    sign_in_as(duo.pilot)
    get game_path(game)
    assert_select "#role", I18n.t("games.role.pilot", judge: duo.judge.nickname)

    sign_in_as(duo.judge)
    get game_path(game)
    assert_select "#role", I18n.t("games.role.judge", pilot: duo.pilot.nickname)
  end

  test "un joueur qui a abandonné le voit dans son bandeau" do
    game = build_game(players: 6, started: true)
    leaver = game.current_cup.duos.find { |duo| duo.judge != game.current_cup.game_master }.pilot
    ReplacementService.abandon!(game: game, by: game.host, player: leaver)
    sign_in_as(leaver)

    get game_path(game)

    assert_select "#role", I18n.t("games.role.abandoned")
  end

  test "pas de bandeau de rôle dans le lobby" do
    game = build_game(players: 4)
    sign_in_as(game.host)

    get game_path(game)

    assert_select "#role", false
  end
end
