require "application_system_test_case"

# rules.md §2, §5 : lobby en direct sur plusieurs téléphones, lancement par l'hôte.
class LobbyTest < ApplicationSystemTestCase
  test "l'hôte voit arriver les joueurs en direct puis lance la partie pour tout le monde" do
    host_session = Capybara.current_session
    visit root_path
    within("form[action='#{games_path}']") do
      fill_in "Pseudo", with: "Hôte"
      click_button "Créer"
    end
    code = find("#game_code").text
    assert_text "Joueurs (1/9)"

    Capybara.using_session("luigi") do
      visit root_path
      within("form[action='#{joins_path}']") do
        fill_in "Code de la partie", with: code
        fill_in "Pseudo", with: "Luigi"
        click_button "Rejoindre"
      end
      assert_text "En attente du lancement par l'hôte"
    end

    host_session.assert_text "Joueurs (2/9)"
    host_session.assert_no_selector :button, "Lancer la partie"

    game = Game.find_by!(code: code)
    game.players.create!(nickname: "Peach")
    game.players.create!(nickname: "Yoshi")

    assert_text "Joueurs (4/9)"
    click_button "Lancer la partie"
    assert_text "La partie est lancée."

    Capybara.using_session("luigi") { assert_text "La partie est lancée." }
  end

  test "le MJ juge choisit le personnage de son pilote et les autres le voient en direct" do
    visit root_path
    within("form[action='#{games_path}']") do
      fill_in "Pseudo", with: "Hôte"
      click_button "Créer"
    end
    code = find("#game_code").text

    Capybara.using_session("luigi") do
      visit root_path
      within("form[action='#{joins_path}']") do
        fill_in "Code de la partie", with: code
        fill_in "Pseudo", with: "Luigi"
        click_button "Rejoindre"
      end
      assert_text "En attente du lancement par l'hôte"
    end
    game = Game.find_by!(code: code)
    game.players.create!(nickname: "Peach")
    game.players.create!(nickname: "Yoshi")

    assert_text "Joueurs (4/9)"
    fill_in "Nombre de coupes", with: "2"
    click_button "Lancer la partie"
    assert_text "Coupe 1/2"
    assert_selector "#game_master", text: "Hôte"
    assert_selector "#duos li", count: 2

    select "Mario", from: "character"
    click_button "Choisir"

    Capybara.using_session("luigi") do
      assert_text "Coupe 1/2"
      assert_text "Personnage : Mario"
    end
  end

  test "le MJ mène une course : lancement, case cochée par le juge, validation, classement" do
    load_catalog
    visit root_path
    within("form[action='#{games_path}']") do
      fill_in "Pseudo", with: "Hôte"
      click_button "Créer"
    end
    code = find("#game_code").text

    Capybara.using_session("luigi") do
      visit root_path
      within("form[action='#{joins_path}']") do
        fill_in "Code de la partie", with: code
        fill_in "Pseudo", with: "Luigi"
        click_button "Rejoindre"
      end
      assert_text "En attente du lancement par l'hôte"
    end
    game = Game.find_by!(code: code)
    game.players.create!(nickname: "Peach")
    game.players.create!(nickname: "Yoshi")

    assert_text "Joueurs (4/9)"
    click_button "Lancer la partie"
    assert_text "Coupe 1/2"

    own_duo = game.current_cup.duos.find { |duo| duo.judge == game.host }
    (game.current_cup.duos - [ own_duo ]).each { |duo| duo.update!(character: "Wario") }
    select "Mario", from: "character"
    click_button "Choisir"
    click_button "Lancer la coupe"
    assert_text "Course 1/4"
    assert_selector "#my_duo li.check", count: 3

    click_button "Lancer la course"
    Capybara.using_session("luigi") { assert_text "Course 1/4" }
    within("li.check[data-kind='fil_rouge']") { click_button "Marquer comme réussie" }
    assert_selector "li.check[data-kind='fil_rouge'] button", text: "Annuler"

    click_button "Valider la course"
    assert_text "Course 2/4"
    assert_selector "#ranking li", count: 4
    assert_selector ".race-result", count: 1
    assert_equal 1, game.current_cup.races.where(status: "finished").count
  end

  test "le MJ déclare un abandon et une nouvelle personne reprend le siège avec le code" do
    visit root_path
    within("form[action='#{games_path}']") do
      fill_in "Pseudo", with: "Hôte"
      click_button "Créer"
    end
    code = find("#game_code").text
    game = Game.find_by!(code: code)
    %w[Luigi Peach Yoshi].each { |nickname| game.players.create!(nickname: nickname) }

    assert_text "Joueurs (4/9)"
    click_button "Lancer la partie"
    assert_text "Coupe 1/2"

    find("summary", text: "Gérer les joueurs").click
    accept_confirm { click_button "Luigi abandonne" }
    assert_selector ".open-seat", text: "Luigi a abandonné"

    Capybara.using_session("relève") do
      visit root_path
      within("form[action='#{joins_path}']") do
        fill_in "Code de la partie", with: code
        fill_in "Pseudo", with: "Relève"
        click_button "Rejoindre"
      end
      assert_text "Coupe 1/2"
      assert_text "Relève"
    end

    assert_no_selector ".open-seat"
    assert_text "Luigi (abandon)"
  end

  test "un pseudo déjà pris affiche une erreur" do
    game = build_game(players: 2)
    visit root_path

    within("form[action='#{joins_path}']") do
      fill_in "Code de la partie", with: game.code
      fill_in "Pseudo", with: "Joueur 2"
      click_button "Rejoindre"
    end

    assert_text "Le pseudo est déjà utilisé"
  end
end
