require "test_helper"

# Parties complètes de 4 à 9 joueurs : le déroulement est rejoué avec des graines fixes et comparé au résultat
# figé dans test/golden/data. Toute différence signale un changement de règle ou une régression.
#
# Changement de règle voulu : relancer avec UPDATE_GOLDEN=1, relire le diff des fichiers .yml, puis les valider.
class GoldenGamesTest < ActiveSupport::TestCase
  include GameInvariants

  DATA_DIR = Rails.root.join("test/golden/data")

  setup { load_catalog }

  def play(count, seed:, cups_count:)
    draws = Random.new(seed)
    game = build_game(players: count, started: true, cups_count: cups_count, random: draws)
    GameSimulator.new(game, draws: draws, script: Random.new(seed + 10_000)).play!
  end

  def first_difference(expected, actual)
    expected_lines = expected.lines
    actual_lines = actual.lines
    index = (0...[ expected_lines.size, actual_lines.size ].max).find { |line| expected_lines[line] != actual_lines[line] }

    "première différence ligne #{index + 1} :\n  figé  : #{expected_lines[index]&.strip}\n  obtenu : #{actual_lines[index]&.strip}\n" \
      "Si le changement est voulu : UPDATE_GOLDEN=1 docker compose run --rm web bin/rails test test/golden"
  end

  (4..9).each do |count|
    test "partie complète à #{count} joueurs : résultat figé" do
      cycle = CupCountCalculator.new(count).full_cycle
      simulator = play(count, seed: count, cups_count: cycle)
      assert_game_invariants(simulator.game, extra_gap: 2 * simulator.swaps_applied)

      actual = simulator.snapshot.to_yaml
      file = DATA_DIR.join("players_#{count}.yml")
      if ENV["UPDATE_GOLDEN"] == "1"
        FileUtils.mkdir_p(DATA_DIR)
        File.write(file, actual)
      else
        assert file.exist?, "#{file} est absent : le générer avec UPDATE_GOLDEN=1"
        expected = File.read(file)
        assert_equal expected, actual, -> { first_difference(expected, actual) }
      end
    end
  end

  test "le même scénario rejoué deux fois donne exactement la même partie" do
    first = play(5, seed: 42, cups_count: 2).snapshot
    second = play(5, seed: 42, cups_count: 2).snapshot

    assert_equal first, second
  end

  test "une autre graine donne une autre partie" do
    first = play(6, seed: 1, cups_count: 2).snapshot
    second = play(6, seed: 2, cups_count: 2).snapshot

    assert_not_equal first["cups"], second["cups"]
  end

  test "les scénarios figés contiennent des contestations, un abandon et des complications variées" do
    snapshots = (4..9).map { |count| YAML.safe_load_file(DATA_DIR.join("players_#{count}.yml")) }

    assert snapshots.sum { |snapshot| snapshot["disputes"].size } >= 6
    assert snapshots.all? { |snapshot| snapshot["abandoned"].one? }
    complications = snapshots.flat_map { |snapshot| snapshot["cups"].flat_map { |cup| cup["races"].map { |race| race["complication"] } } }
    assert_equal ComplicationResolver::KEYS.sort, complications.uniq.sort
    assert snapshots.all? { |snapshot| snapshot["status"] == "finished" }
  end
end
