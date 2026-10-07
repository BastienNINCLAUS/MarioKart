require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 390, 844 ] do |options|
    options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"]
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
  end

  # Aucun débordement horizontal sur un écran de téléphone (390 px).
  def assert_no_horizontal_overflow
    overflow = page.evaluate_script("document.documentElement.scrollWidth - window.innerWidth")

    assert_operator overflow, :<=, 0, "la page déborde de #{overflow}px"
  end

  # Boutons et champs assez grands pour le doigt.
  def assert_touch_targets(minimum = 44)
    small = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll("button, input[type=submit], select, input[type=text], input[type=number]"))
        .filter(el => el.offsetParent !== null && el.getBoundingClientRect().height < #{minimum})
        .map(el => el.outerHTML.slice(0, 80))
    JS

    assert_empty small, "éléments trop petits : #{small}"
  end

  # L'hôte crée une partie dans la session courante ; Luigi la rejoint dans la session "luigi" ; Peach et Yoshi
  # sont ajoutés en base. Retourne la partie en lobby avec ses 4 joueurs.
  def create_lobby_with_four_players
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
    game
  end
end
