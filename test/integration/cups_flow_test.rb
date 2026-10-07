require "test_helper"

# rules.md §4, §6 : lancement avec nombre de coupes, rôles visibles, personnage choisi par le juge, ajustement par le MJ.
class CupsFlowTest < ActionDispatch::IntegrationTest
  test "l'hôte choisit le nombre de coupes au lancement" do
    game = build_game(players: 5)
    sign_in_as(game.host)

    post start_game_path(game), params: { cups_count: "4" }

    assert_equal 4, game.reload.cups_count
    assert_equal 1, game.cups.count
  end

  test "un nombre de coupes invalide est refusé avec un message" do
    game = build_game(players: 5)
    sign_in_as(game.host)

    post start_game_path(game), params: { cups_count: "99" }

    assert_equal I18n.t("games.start_errors.invalid_cups_count", min: 2, max: 12), flash[:alert]
    assert game.reload.lobby?
  end

  test "le formulaire de lancement propose le cycle équitable" do
    game = build_game(players: 5)
    sign_in_as(game.host)

    get game_path(game)

    assert_select "input[name=cups_count][value='2'][min='2'][max='12']"
    assert_select "p", I18n.t("games.show.cups_hint", cycle: 5)
  end

  test "tous les joueurs voient le MJ, les duos et leurs rôles" do
    game = build_game(players: 6, started: true)
    cup = game.current_cup
    sign_in_as(game.players.find_by!(nickname: "Joueur 3"))

    get game_path(game)

    assert_select "h2", I18n.t("games.cup.heading", position: 1, total: 2)
    assert_select "#game_master", cup.game_master.nickname
    assert_select "#duos li", 3
    cup.duos.each do |duo|
      assert_select "#duos li", text: /#{duo.pilot.nickname}.*#{duo.judge.nickname}/m
    end
  end

  test "seul le juge d'un duo voit le choix du personnage de son pilote" do
    game = build_game(players: 4, started: true)
    duo = game.current_cup.duos.first
    sign_in_as(duo.judge)

    get game_path(game)
    assert_select "form[action='#{game_duo_path(game, duo)}']"
    assert_select "form[action^='/games/#{game.code}/duos/']", 1

    sign_in_as(duo.pilot)
    get game_path(game)
    assert_select "form[action='#{game_duo_path(game, duo)}']", false
  end

  test "le juge choisit le personnage de son pilote" do
    game = build_game(players: 4, started: true)
    duo = game.current_cup.duos.first
    sign_in_as(duo.judge)

    patch game_duo_path(game, duo), params: { character: "Yoshi" }

    assert_redirected_to game_path(game)
    assert_equal "Yoshi", duo.reload.character
  end

  test "le personnage peut être retiré" do
    game = build_game(players: 4, started: true)
    duo = game.current_cup.duos.first
    duo.update!(character: "Yoshi")
    sign_in_as(duo.judge)

    patch game_duo_path(game, duo), params: { character: "" }

    assert_nil duo.reload.character
  end

  test "un personnage déjà pris ou inconnu est refusé" do
    game = build_game(players: 4, started: true)
    first, second = game.current_cup.duos.first(2)
    first.update!(character: "Yoshi")
    sign_in_as(second.judge)

    patch game_duo_path(game, second), params: { character: "Yoshi" }
    assert_not_nil flash[:alert]
    assert_nil second.reload.character

    patch game_duo_path(game, second), params: { character: "Inconnu" }
    assert_not_nil flash[:alert]
    assert_nil second.reload.character
  end

  test "un autre joueur ne peut pas choisir le personnage" do
    game = build_game(players: 4, started: true)
    duo = game.current_cup.duos.first
    sign_in_as(duo.pilot)

    patch game_duo_path(game, duo), params: { character: "Yoshi" }

    assert_equal I18n.t("duos.errors.not_judge"), flash[:alert]
    assert_nil duo.reload.character
  end

  test "le personnage ne change plus une fois la coupe commencée" do
    game = build_game(players: 4, started: true)
    duo = game.current_cup.duos.first
    game.current_cup.in_progress!
    sign_in_as(duo.judge)

    patch game_duo_path(game, duo), params: { character: "Yoshi" }

    assert_equal I18n.t("duos.errors.cup_started"), flash[:alert]
    assert_nil duo.reload.character
  end

  test "un non-membre ne peut pas choisir de personnage" do
    game = build_game(players: 4, started: true)
    duo = game.current_cup.duos.first

    patch game_duo_path(game, duo), params: { character: "Yoshi" }

    assert_redirected_to root_path(code: game.code)
    assert_nil duo.reload.character
  end

  test "le MJ échange deux joueurs" do
    game = build_game(players: 6, started: true)
    cup = game.current_cup
    first, second = cup.duos.first(2)
    sign_in_as(cup.game_master)

    patch swap_game_cup_path(game, cup), params: { player_id: first.pilot_id, other_id: second.pilot_id }

    assert_redirected_to game_path(game)
    assert_equal [ second.pilot_id, first.pilot_id ], [ first.reload.pilot_id, second.reload.pilot_id ]
  end

  test "le MJ voit le formulaire d'ajustement, pas les autres" do
    game = build_game(players: 6, started: true)
    cup = game.current_cup
    sign_in_as(cup.game_master)
    get game_path(game)
    assert_select "form[action='#{swap_game_cup_path(game, cup)}']"

    sign_in_as(cup.duos.first.pilot)
    get game_path(game)
    assert_select "form[action='#{swap_game_cup_path(game, cup)}']", false
  end

  test "un échange invalide affiche une erreur" do
    game = build_game(players: 6, started: true)
    cup = game.current_cup
    sign_in_as(cup.game_master)

    patch swap_game_cup_path(game, cup), params: { player_id: cup.game_master_id, other_id: cup.duos.first.pilot_id }

    assert_equal I18n.t("cups.swap_errors.game_master_cannot_pilot"), flash[:alert]
  end

  test "un joueur qui n'est pas MJ ne peut pas ajuster les rôles" do
    game = build_game(players: 6, started: true)
    cup = game.current_cup
    first, second = cup.duos.first(2)
    sign_in_as(first.pilot)

    patch swap_game_cup_path(game, cup), params: { player_id: first.pilot_id, other_id: second.pilot_id }

    assert_equal I18n.t("cups.errors.not_game_master"), flash[:alert]
    assert_equal first.pilot_id, first.reload.pilot_id
  end
end
