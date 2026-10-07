require "application_system_test_case"

# Confidentialité en direct : chaque téléphone ne reçoit que les secrets de son propre duo.
class PrivacyTest < ApplicationSystemTestCase
  test "chacun ne voit que les secrets de son duo, avant et après le départ de la course" do
    load_catalog
    game = create_lobby_with_four_players
    click_button "Lancer la partie"
    assert_text "Coupe 1/2"
    game.current_cup.duos.each_with_index { |duo, index| duo.update!(character: Characters::ALL[index]) }
    click_button "Lancer la coupe"
    assert_text "Course 1/4"

    cup = game.current_cup
    race = cup.current_race
    secrets = cup.duos.to_h do |duo|
      secret_task = race.checks.find { |check| check.duo_id == duo.id && check.secret_task? }.catalog_item
      [ duo, [ duo.fil_rouge_item, duo.special_action_item, secret_task ].map(&:description) ]
    end

    check_visibility = lambda do |nickname|
      player = game.players.find_by!(nickname: nickname)
      secrets.each do |duo, texts|
        texts.each { |text| duo.member?(player) ? assert_text(text) : assert_no_text(text) }
      end
    end

    check_visibility.call("Hôte")
    Capybara.using_session("luigi") do
      assert_text "Course 1/4"
      check_visibility.call("Luigi")
    end

    click_button "Lancer la course"
    assert_text "en cours"
    check_visibility.call("Hôte")
    Capybara.using_session("luigi") do
      assert_text "en cours"
      check_visibility.call("Luigi")
    end
  end
end
