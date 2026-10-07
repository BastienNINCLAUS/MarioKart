require "application_system_test_case"

# Quatre téléphones (4 sessions de navigateur) jouent une partie complète par l'interface seulement.
class FullGameTest < ApplicationSystemTestCase
  include GameInvariants

  SESSIONS = { "Hôte" => :default, "Luigi" => "luigi", "Peach" => "peach", "Yoshi" => "yoshi" }.freeze

  def as(nickname, &block)
    Capybara.using_session(SESSIONS.fetch(nickname), &block)
  end

  def every_session
    SESSIONS.each_key.map { |nickname| as(nickname) { yield nickname } }
  end

  def join(code, nickname)
    as(nickname) do
      visit root_path
      within("form[action='#{joins_path}']") do
        fill_in "Code de la partie", with: code
        fill_in "Pseudo", with: nickname
        click_button "Rejoindre"
      end
      assert_text "En attente du lancement par l'hôte"
    end
  end

  def choose_characters(game)
    game.current_cup.duos.each_with_index do |duo, index|
      as(duo.judge.nickname) do
        select Characters::ALL[index], from: "character"
        click_button "Choisir"
      end
    end
  end

  def tick_first_task
    within("li.check[data-kind='fil_rouge']") { click_button "Marquer comme réussie" }
    assert_selector "li.check[data-kind='fil_rouge'] button", text: "Annuler"
  end

  test "une partie complète de 2 coupes se joue sur 4 téléphones jusqu'au classement final identique partout" do
    load_catalog
    Capybara.using_wait_time(8) do
      visit root_path
      within("form[action='#{games_path}']") do
        fill_in "Pseudo", with: "Hôte"
        click_button "Créer"
      end
      code = find("#game_code").text
      %w[Luigi Peach Yoshi].each { |nickname| join(code, nickname) }
      assert_text "Joueurs (4/9)"
      click_button "Lancer la partie"
      game = Game.find_by!(code: code)

      2.times do |cup_index|
        every_session { assert_text "Coupe #{cup_index + 1}/2" }
        choose_characters(game)
        master = game.current_cup.game_master.nickname
        as(master) { click_button "Lancer la coupe" }

        Cup::RACES_COUNT.times do |race_index|
          every_session { assert_text "Course #{race_index + 1}/4" }
          judges = game.current_cup.duos.map { |duo| duo.judge.nickname }
          as(master) { click_button "Lancer la course" }
          every_session { assert_text "en cours" }
          judges.each { |nickname| as(nickname) { tick_first_task } }
          as(master) { click_button "Valider la course" }
        end
      end

      every_session { assert_text "La partie est terminée." }
      rankings = every_session { find("#ranking").text }

      assert_equal 1, rankings.uniq.size, "le classement doit être identique sur tous les téléphones"
      game.ranking.each do |entry|
        assert_includes rankings.first, "#{entry.rank}. #{game.players.find(entry.player).nickname}"
      end
      assert_game_invariants(game)
      assert_equal 8, Race.joins(:cup).where(cups: { game_id: game.id }).finished.count
    end
  end
end
