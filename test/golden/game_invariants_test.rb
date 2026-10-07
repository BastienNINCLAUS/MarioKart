require "test_helper"

# Mêmes invariants que les parties figées, sur de nombreuses graines et tous les effectifs.
class GameInvariantsTest < ActiveSupport::TestCase
  include GameInvariants

  setup { load_catalog }

  test "parties de 2 coupes à 4-9 joueurs, 3 graines chacune, avec et sans remplacement ni échange du MJ" do
    (4..9).each do |count|
      (1..3).each do |seed|
        draws = Random.new(seed * 100 + count)
        game = build_game(players: count, started: true, cups_count: 2, random: draws)
        simulator = GameSimulator.new(game, draws: draws, script: Random.new(seed), replace_a_player: seed != 3,
                                      swap_probability: seed == 3 ? 0 : GameSimulator::SWAP_PROBABILITY).play!

        assert_game_invariants(game, extra_gap: 2 * simulator.swaps_applied)
      end
    end
  end

  test "sans échange du MJ, un cycle complet est parfaitement équitable (même avec un remplacement)" do
    (4..9).each do |count|
      cycle = CupCountCalculator.new(count).full_cycle
      draws = Random.new(count)
      game = build_game(players: count, started: true, cups_count: cycle, random: draws)
      GameSimulator.new(game, draws: draws, script: Random.new(count), swap_probability: 0).play!

      assert_game_invariants(game)
    end
  end

  test "parties de 4 coupes sans rotation du MJ : l'hôte reste MJ" do
    [ 4, 7 ].each do |count|
      draws = Random.new(count)
      game = build_game(players: count, started: true, cups_count: 4, rotate_game_master: false, random: draws)
      GameSimulator.new(game, draws: draws, script: Random.new(count), replace_a_player: false).play!

      assert_equal [ game.host_id ], game.cups.map(&:game_master_id).uniq
      assert_equal 4, game.cups.count
    end
  end
end
