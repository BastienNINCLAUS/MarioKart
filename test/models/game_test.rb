require "test_helper"

# rules.md §2 (joueurs 4 à 9, hôte administrateur) et §5 (lancement par l'hôte).
class GameTest < ActiveSupport::TestCase
  test "un code unique de 5 caractères sans ambiguïté est généré" do
    game = Game.create!

    assert_match(/\A[A-HJ-NP-Z2-9]{5}\z/, game.code)
    assert_equal game.code, game.to_param
  end

  test "deux parties n'ont jamais le même code" do
    codes = Array.new(30) { Game.create!.code }

    assert_equal codes.uniq.size, codes.size
  end

  test "un code déjà pris est régénéré" do
    taken = Game.create!(code: "AAAAA")
    candidates = [ taken.code, "BBBBB" ]
    original = Game.method(:generate_code)
    Game.define_singleton_method(:generate_code) { candidates.shift }

    assert_equal "BBBBB", Game.create!.code
  ensure
    Game.define_singleton_method(:generate_code, original)
  end

  test "create_with_host! crée la partie en lobby avec son hôte comme premier joueur" do
    game = Game.create_with_host!(nickname: "Mario", rotate_game_master: false)

    assert game.lobby?
    assert_not game.rotate_game_master
    assert_equal [ "Mario" ], game.players.map(&:nickname)
    assert game.host.host?
  end

  test "la rotation du maître du jeu est activée par défaut" do
    assert Game.create_with_host!(nickname: "Mario").rotate_game_master
  end

  test "create_with_host! ne crée rien si le pseudo est invalide" do
    assert_no_difference [ "Game.count", "Player.count" ] do
      assert_raises(ActiveRecord::RecordInvalid) { Game.create_with_host!(nickname: "") }
    end
  end

  test "l'hôte lance la partie avec 4 à 9 joueurs" do
    (Game::MIN_PLAYERS..Game::MAX_PLAYERS).each do |count|
      game = build_game(players: count)
      game.start!(by: game.host)

      assert game.in_progress?, "#{count} joueurs devraient pouvoir lancer la partie"
    end
  end

  test "le lancement est refusé sous 4 joueurs" do
    game = build_game(players: 3)
    error = assert_raises(Game::CannotStart) { game.start!(by: game.host) }

    assert_equal :wrong_player_count, error.reason
    assert game.reload.lobby?
  end

  test "seul l'hôte peut lancer la partie" do
    game = build_game(players: 5)
    other = game.players.where.not(id: game.host_id).first

    assert_equal :not_host, assert_raises(Game::CannotStart) { game.start!(by: other) }.reason
    assert_equal :not_host, assert_raises(Game::CannotStart) { game.start!(by: nil) }.reason
    assert game.reload.lobby?
  end

  test "une partie déjà lancée ne peut pas être relancée" do
    game = build_game(players: 4, started: true)

    assert_equal :not_lobby, assert_raises(Game::CannotStart) { game.start!(by: game.host) }.reason
  end

  test "le lancement diffuse un rafraîchissement à tous les joueurs du lobby" do
    game = build_game(players: 4)

    assert_turbo_stream_broadcasts(game, count: 1) { game.start!(by: game.host) }
  end

  test "le lancement fixe 2 coupes par défaut et prépare la première coupe avec l'hôte MJ" do
    game = build_game(players: 5, started: true)

    assert_equal 2, game.cups_count
    assert_equal 1, game.cups.count
    assert_equal game.host, game.current_cup.game_master
    assert_equal 2, game.current_cup.duos.size
    assert game.current_cup.roles_valid?
  end

  test "l'hôte peut augmenter le nombre de coupes" do
    game = build_game(players: 5, started: true, cups_count: "5")

    assert_equal 5, game.cups_count
  end

  test "un nombre de coupes invalide refuse le lancement sans rien créer" do
    [ "1", "13", "abc", "2.5" ].each do |value|
      game = build_game(players: 4)
      error = assert_raises(Game::CannotStart) { game.start!(by: game.host, cups_count: value) }

      assert_equal :invalid_cups_count, error.reason, value
      assert game.reload.lobby?
      assert_equal 0, game.cups.count
    end
  end

  test "sans rotation, l'hôte est MJ de toutes les coupes" do
    game = build_game(players: 6, started: true, rotate_game_master: false, cups_count: 3)
    masters = [ game.current_cup.game_master ]
    2.times do
      game.current_cup.finished!
      masters << game.setup_next_cup!(random: seeded_random).game_master
    end

    assert_equal [ game.host ], masters.uniq
  end

  test "avec rotation, le MJ change à chaque coupe dans l'ordre d'arrivée" do
    game = build_game(players: 4, started: true, cups_count: 4)
    masters = [ game.current_cup.game_master ]
    3.times do
      game.current_cup.finished!
      masters << game.setup_next_cup!(random: seeded_random).game_master
    end

    assert_equal game.rotation_order, masters
  end

  test "une partie complète équitable : chacun pilote autant de fois sur un cycle complet" do
    (4..9).each do |count|
      cycle = CupCountCalculator.new(count).full_cycle
      game = build_game(players: count, started: true, cups_count: cycle, random: seeded_random(count))
      (cycle - 1).times do
        game.current_cup.finished!
        game.setup_next_cup!(random: seeded_random(count))
      end
      counts = Duo.joins(:cup).where(cups: { game_id: game.id }).group(:pilot_id).count

      assert_equal cycle, game.cups.count
      assert_equal count, counts.size, "#{count} joueurs : tous ont piloté"
      assert_equal 1, counts.values.uniq.size, "#{count} joueurs : #{counts}"
      assert game.cups.all?(&:roles_valid?)
    end
  end

  test "setup_next_cup! exige une partie en cours, une coupe précédente terminée et des coupes restantes" do
    assert_raises(Game::CannotSetupCup) { build_game.setup_next_cup! }

    game = build_game(players: 4, started: true, cups_count: 2)
    assert_raises(Game::CannotSetupCup) { game.setup_next_cup! }

    game.current_cup.finished!
    game.setup_next_cup!
    game.current_cup.finished!
    assert_raises(Game::CannotSetupCup) { game.setup_next_cup! }
  end
end
