require "test_helper"

# rules.md §2, §5 : créer, rejoindre, reconnexion, lancement par l'hôte uniquement.
class LobbyFlowTest < ActionDispatch::IntegrationTest
  test "l'accueil propose de créer et de rejoindre une partie" do
    get root_path

    assert_response :success
    assert_select "form[action='#{games_path}']"
    assert_select "form[action='#{joins_path}']"
  end

  test "créer une partie fait de son créateur l'hôte et l'affiche dans le lobby" do
    assert_difference "Game.count", 1 do
      post games_path, params: { nickname: "Mario" }
    end
    game = Game.last

    assert_redirected_to game_path(game)
    assert_not game.rotate_game_master.nil?
    follow_redirect!
    assert_select "#game_code", game.code
    assert_select "#players li", 1
  end

  test "la rotation du MJ peut être désactivée à la création" do
    post games_path, params: { nickname: "Mario", rotate_game_master: "0" }

    assert_not Game.last.rotate_game_master
  end

  test "créer une partie sans pseudo affiche une erreur" do
    assert_no_difference "Game.count" do
      post games_path, params: { nickname: "" }
    end

    assert_response :unprocessable_content
  end

  test "rejoindre avec le code (insensible à la casse) ajoute le joueur au lobby" do
    game = build_game(players: 1)

    assert_difference "game.players.count", 1 do
      post joins_path, params: { code: game.code.downcase, nickname: "Luigi" }
    end
    assert_redirected_to game_path(game)
    follow_redirect!
    assert_select "#players li", 2
  end

  test "un code inconnu est refusé" do
    post joins_path, params: { code: "ZZZZZ", nickname: "Luigi" }

    assert_response :unprocessable_content
    assert_select "[role=alert]", I18n.t("joins.create.unknown_code")
  end

  test "un pseudo déjà pris par un autre téléphone est refusé" do
    game = build_game(players: 2)

    assert_no_difference "game.players.count" do
      post joins_path, params: { code: game.code, nickname: "joueur 2" }
    end
    assert_response :unprocessable_content
  end

  test "reconnexion : même téléphone et même pseudo ne crée pas de doublon" do
    game = build_game(players: 2)
    player = game.players.find_by!(nickname: "Joueur 2")
    sign_in_as(player)

    assert_no_difference "game.players.count" do
      post joins_path, params: { code: game.code, nickname: "joueur 2" }
    end
    assert_redirected_to game_path(game)
  end

  test "impossible de rejoindre une partie complète ou lancée" do
    full = build_game(players: Game::MAX_PLAYERS)
    post joins_path, params: { code: full.code, nickname: "Dixième" }
    assert_response :unprocessable_content

    started = build_game(players: 4, started: true)
    post joins_path, params: { code: started.code, nickname: "Retardataire" }
    assert_response :unprocessable_content
    assert_nil started.players.find_by(nickname: "Retardataire")
  end

  test "un non-membre est renvoyé vers l'accueil avec le code prérempli" do
    game = build_game

    get game_path(game)

    assert_redirected_to root_path(code: game.code)
  end

  test "un joueur n'est pas membre des autres parties" do
    game = build_game
    other = build_game
    sign_in_as(game.host)

    get game_path(other)

    assert_redirected_to root_path(code: other.code)
  end

  test "l'hôte voit le bouton de lancement uniquement avec 4 à 9 joueurs" do
    small = build_game(players: 3)
    sign_in_as(small.host)
    get game_path(small)
    assert_select "form[action='#{start_game_path(small)}']", false

    enough = build_game(players: 4)
    sign_in_as(enough.host)
    get game_path(enough)
    assert_select "form[action='#{start_game_path(enough)}']"
  end

  test "un joueur non hôte ne voit pas le bouton de lancement" do
    game = build_game
    sign_in_as(game.players.find_by!(nickname: "Joueur 2"))

    get game_path(game)

    assert_select "form[action='#{start_game_path(game)}']", false
  end

  test "l'hôte lance la partie" do
    game = build_game(players: 5)
    sign_in_as(game.host)

    post start_game_path(game)

    assert_redirected_to game_path(game)
    assert game.reload.in_progress?
  end

  test "un joueur non hôte ne peut pas lancer la partie" do
    game = build_game(players: 5)
    sign_in_as(game.players.find_by!(nickname: "Joueur 2"))

    post start_game_path(game)

    assert_redirected_to game_path(game)
    assert_equal I18n.t("games.start_errors.not_host"), flash[:alert]
    assert game.reload.lobby?
  end

  test "un non-membre ne peut pas lancer la partie" do
    game = build_game(players: 5)

    post start_game_path(game)

    assert_redirected_to root_path(code: game.code)
    assert game.reload.lobby?
  end

  test "le lancement sous 4 joueurs est refusé avec un message" do
    game = build_game(players: 3)
    sign_in_as(game.host)

    post start_game_path(game)

    assert_equal I18n.t("games.start_errors.wrong_player_count"), flash[:alert]
    assert game.reload.lobby?
  end

  test "après le lancement, les joueurs voient que la partie est en cours" do
    game = build_game(players: 4, started: true)
    sign_in_as(game.host)

    get game_path(game)

    assert_select "p", I18n.t("games.show.in_progress")
  end

  test "une partie inconnue renvoie 404" do
    get game_path("ZZZZZ")

    assert_response :not_found
  end
end
