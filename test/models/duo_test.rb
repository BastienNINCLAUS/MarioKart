require "test_helper"

class DuoTest < ActiveSupport::TestCase
  setup do
    @game = build_game(players: 6, started: true)
    @cup = @game.current_cup
    @duo, @other = @cup.duos.first(2)
  end

  test "la liste des personnages est sans doublon" do
    assert_equal Characters::ALL.uniq, Characters::ALL
  end

  test "le personnage est optionnel mais doit appartenir à la liste" do
    assert @duo.valid?

    @duo.character = "Inconnu"
    assert_not @duo.valid?

    @duo.character = "Mario"
    assert @duo.valid?
  end

  test "un personnage ne peut être pris que par un seul duo de la coupe" do
    @duo.update!(character: "Mario")
    @other.character = "Mario"

    assert_not @other.valid?
  end

  test "le même personnage est possible dans une autre coupe" do
    @duo.update!(character: "Mario")
    @cup.finished!
    next_cup = @game.setup_next_cup!(random: seeded_random)

    assert next_cup.duos.first.tap { |duo| duo.character = "Mario" }.valid?
  end

  test "le pilote et le juge doivent être différents" do
    @duo.judge = @duo.pilot

    assert_not @duo.valid?
  end

  test "le MJ ne peut pas être pilote" do
    @duo.pilot = @cup.game_master

    assert_not @duo.valid?
  end

  test "les joueurs d'un duo appartiennent à la partie" do
    @duo.pilot = build_game.host

    assert_not @duo.valid?
  end
end
