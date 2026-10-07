require "test_helper"

# rules.md §4 : le MJ peut ajuster le tirage automatique des rôles avant la coupe.
class RoleAdjusterTest < ActiveSupport::TestCase
  setup do
    @game = build_game(players: 6, started: true)
    @cup = @game.current_cup
    @first = @cup.duos.first
    @second = @cup.duos.find { |duo| duo != @first && duo.judge != @cup.game_master }
  end

  test "échanger deux juges change leurs pilotes et garde des rôles valides" do
    judge_a, judge_b = @first.judge, @second.judge

    RoleAdjuster.swap!(cup: @cup, player: judge_a, other: judge_b)

    assert_equal judge_b, @first.reload.judge
    assert_equal judge_a, @second.reload.judge
    assert @cup.reload.roles_valid?
  end

  test "échanger un pilote et un juge change les rôles et efface le personnage du pilote remplacé" do
    @first.update!(character: "Mario")
    pilot, judge = @first.pilot, @second.judge

    RoleAdjuster.swap!(cup: @cup, player: pilot, other: judge)

    assert_equal judge, @first.reload.pilot
    assert_equal pilot, @second.reload.judge
    assert_nil @first.character
    assert @cup.reload.roles_valid?
  end

  test "échanger le pilote et le juge d'un même duo inverse leurs rôles" do
    pilot, judge = @first.pilot, @first.judge

    RoleAdjuster.swap!(cup: @cup, player: pilot, other: judge)

    assert_equal [ judge, pilot ], [ @first.reload.pilot, @first.judge ]
  end

  test "le MJ, juge à effectif pair, peut échanger sa place avec un autre juge" do
    master = @cup.game_master
    other_judge = @cup.duos.map(&:judge).find { |judge| judge != master }

    RoleAdjuster.swap!(cup: @cup, player: master, other: other_judge)

    assert @cup.reload.roles_valid?
    assert_equal master, @cup.game_master
  end

  test "le MJ ne peut pas devenir pilote" do
    pilot = @first.pilot

    error = assert_raises(RoleAdjuster::Invalid) { RoleAdjuster.swap!(cup: @cup, player: @cup.game_master, other: pilot) }

    assert_equal :game_master_cannot_pilot, error.reason
    assert @cup.reload.roles_valid?
  end

  test "le MJ qui ne joue pas (effectif impair) ne peut pas être échangé" do
    game = build_game(players: 5, started: true)
    cup = game.current_cup

    error = assert_raises(RoleAdjuster::Invalid) { RoleAdjuster.swap!(cup: cup, player: cup.game_master, other: cup.duos.first.judge) }

    assert_equal :not_in_duo, error.reason
  end

  test "on ne peut pas échanger un joueur avec lui-même" do
    error = assert_raises(RoleAdjuster::Invalid) { RoleAdjuster.swap!(cup: @cup, player: @first.pilot, other: @first.pilot) }

    assert_equal :same_player, error.reason
  end

  test "l'ajustement est refusé une fois la coupe commencée" do
    @cup.in_progress!

    error = assert_raises(RoleAdjuster::Invalid) { RoleAdjuster.swap!(cup: @cup, player: @first.pilot, other: @second.pilot) }

    assert_equal :not_setup, error.reason
  end
end
