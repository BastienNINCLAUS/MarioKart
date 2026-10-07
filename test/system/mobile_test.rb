require "application_system_test_case"

# Mobile d'abord (390 px) : pas de défilement horizontal, cibles tactiles assez grandes, bandeau de rôle.
class MobileTest < ApplicationSystemTestCase
  test "accueil, lobby, préparation de coupe et course restent utilisables sur téléphone" do
    load_catalog
    visit root_path
    assert_no_horizontal_overflow
    assert_touch_targets

    game = create_lobby_with_four_players
    assert_no_horizontal_overflow
    assert_touch_targets

    click_button "Lancer la partie"
    assert_text "Coupe 1/2"
    assert_selector "#role", text: "Tu es le maître du jeu et le juge de"
    assert_selector "#game_code", text: game.code
    assert_no_horizontal_overflow
    assert_touch_targets

    own_duo = game.current_cup.duos.find { |duo| duo.judge == game.host }
    (game.current_cup.duos - [ own_duo ]).each { |duo| duo.update!(character: "Wario") }
    select "Mario", from: "character"
    click_button "Choisir"
    click_button "Lancer la coupe"
    assert_text "Course 1/4"
    assert_no_horizontal_overflow
    assert_touch_targets

    click_button "Lancer la course"
    assert_selector "#race form select", count: 2
    within("li.check[data-kind='fil_rouge']") { assert_button "Marquer comme réussie" }
    assert_no_horizontal_overflow
    assert_touch_targets
  end

  test "chaque joueur voit son rôle sur son téléphone" do
    load_catalog
    game = create_lobby_with_four_players
    click_button "Lancer la partie"
    assert_text "Coupe 1/2"

    Capybara.using_session("luigi") do
      assert_text "Coupe 1/2"
      luigi = game.players.find_by!(nickname: "Luigi")
      duo = game.current_cup.duo_for(luigi)
      expected = duo.pilot == luigi ? "Tu es pilote : ton juge est #{duo.judge.nickname}." : "Tu es juge : ton pilote est #{duo.pilot.nickname}."
      assert_selector "#role", text: expected
      assert_no_horizontal_overflow
    end
  end
end
