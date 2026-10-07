require "test_helper"

# rules.md §2 : pseudo, 9 joueurs maximum, pas de nouvel arrivant après le lancement.
class PlayerTest < ActiveSupport::TestCase
  setup { @game = Game.create_with_host!(nickname: "Hôte") }

  test "un jeton de session est généré à la création" do
    player = @game.players.create!(nickname: "Luigi")

    assert_predicate player.session_token, :present?
    assert_not_equal @game.host.session_token, player.session_token
  end

  test "le pseudo est obligatoire et limité à 20 caractères" do
    assert_not @game.players.new(nickname: "").valid?
    assert_not @game.players.new(nickname: "a" * 21).valid?
    assert @game.players.new(nickname: "a" * 20).valid?
  end

  test "le pseudo est nettoyé des espaces superflus" do
    assert_equal "Peach Daisy", @game.players.create!(nickname: "  Peach   Daisy ").nickname
  end

  test "le pseudo est unique dans une partie sans tenir compte de la casse" do
    @game.players.create!(nickname: "Luigi")

    assert_not @game.players.new(nickname: "luigi").valid?
    assert_not @game.players.new(nickname: " LUIGI ").valid?
  end

  test "le même pseudo peut exister dans une autre partie" do
    other = Game.create_with_host!(nickname: "Autre")

    assert other.players.new(nickname: "Hôte").valid?
  end

  test "la partie accepte 9 joueurs puis est complète" do
    (2..Game::MAX_PLAYERS).each { |index| @game.players.create!(nickname: "J#{index}") }
    tenth = @game.players.new(nickname: "J10")

    assert_not tenth.valid?
    assert_includes tenth.errors.full_messages, I18n.t("activerecord.errors.models.player.attributes.base.game_full")
  end

  test "on ne peut plus rejoindre une partie lancée" do
    game = build_game(players: 4, started: true)
    late = game.players.new(nickname: "Retardataire")

    assert_not late.valid?
    assert_includes late.errors.full_messages, I18n.t("activerecord.errors.models.player.attributes.base.game_started")
  end

  test "host? n'est vrai que pour l'hôte" do
    guest = @game.players.create!(nickname: "Luigi")

    assert @game.host.host?
    assert_not guest.host?
  end

  test "un nouveau joueur est connecté par défaut et diffuse un rafraîchissement du lobby" do
    player = nil
    assert_turbo_stream_broadcasts(@game, count: 1) { player = @game.players.create!(nickname: "Luigi") }

    assert player.connected?
  end
end
