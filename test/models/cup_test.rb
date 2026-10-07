require "test_helper"

class CupTest < ActiveSupport::TestCase
  setup do
    @game = build_game(players: 6, started: true)
    @cup = @game.current_cup
  end

  test "la première coupe est en préparation avec un MJ et un duo par pilote" do
    assert @cup.setup?
    assert_equal 1, @cup.position
    assert_equal 3, @cup.duos.size
    assert_equal @game.host, @cup.game_master
    assert @cup.roles_valid?
  end

  test "la position est unique dans la partie" do
    assert_not @game.cups.new(position: 1, game_master: @game.host).valid?
    assert_not @game.cups.new(position: 0, game_master: @game.host).valid?
  end

  test "ready? exige un personnage pour chaque duo" do
    assert_not @cup.ready?

    @cup.duos.each_with_index { |duo, index| duo.update!(character: Characters::ALL[index]) }

    assert @cup.reload.ready?
  end

  test "duo_for retrouve le duo d'un pilote ou d'un juge, et rien pour un MJ qui ne joue pas" do
    duo = @cup.duos.first

    assert_equal duo, @cup.duo_for(duo.pilot)
    assert_equal duo, @cup.duo_for(duo.judge)

    odd = build_game(players: 5, started: true).current_cup
    assert_nil odd.duo_for(odd.game_master)
    assert_not odd.game_master_is_judge?
  end

  test "roles_of donne les rôles d'un joueur dans la coupe" do
    master = @cup.game_master
    pilot = @cup.duos.first.pilot
    judge = @cup.duos.find { |duo| duo.judge != master }.judge

    assert_equal [ :game_master, :judge ], @cup.roles_of(master)
    assert_equal [ :pilot ], @cup.roles_of(pilot)
    assert_equal [ :judge ], @cup.roles_of(judge)
    assert_empty @cup.roles_of(nil)
    assert_empty @cup.roles_of(build_game.host)
  end

  test "roles_of : un MJ qui ne joue pas n'a que le rôle de MJ" do
    odd = build_game(players: 5, started: true).current_cup

    assert_equal [ :game_master ], odd.roles_of(odd.game_master)
  end

  test "roles_valid? détecte un MJ pilote ou un joueur absent" do
    duo = @cup.duos.first
    duo.update_columns(pilot_id: @cup.game_master_id)

    assert_not @cup.reload.roles_valid?
  end

  test "roles_valid? détecte un joueur en double" do
    first, second = @cup.duos.first(2)
    second.update_columns(pilot_id: first.pilot_id)

    assert_not @cup.reload.roles_valid?
  end
end
