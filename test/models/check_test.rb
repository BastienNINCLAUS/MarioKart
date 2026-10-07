require "test_helper"

class CheckTest < ActiveSupport::TestCase
  setup do
    load_catalog
    @game = build_game(players: 4, started: true)
    @cup = start_current_cup(@game)
    @race = @cup.current_race
    @duo = @cup.duos.first
    @fil_rouge = @race.checks.find { |check| check.duo_id == @duo.id && check.fil_rouge? }
    @special = @race.checks.find { |check| check.duo_id == @duo.id && check.special_action? }
    @secret = @race.checks.find { |check| check.duo_id == @duo.id && check.secret_task? }
  end

  test "le juge coche et décoche une tâche pendant la course" do
    @race.start!(by: @cup.game_master)

    @fil_rouge.tick!(by: @duo.judge, achieved: true)
    assert @fil_rouge.reload.achieved?

    @fil_rouge.tick!(by: @duo.judge, achieved: false)
    assert_not @fil_rouge.reload.achieved?
  end

  test "seul le juge du duo peut cocher" do
    @race.start!(by: @cup.game_master)

    [ @duo.pilot, @cup.duos.last.judge, @cup.game_master ].reject { |player| player == @duo.judge }.each do |player|
      assert_equal :not_judge, assert_raises(FlowError) { @fil_rouge.tick!(by: player, achieved: true) }.reason
    end
    assert_not @fil_rouge.reload.achieved?
  end

  test "on ne coche pas avant le départ ni après l'arrivée" do
    assert_equal :race_not_running, assert_raises(FlowError) { @fil_rouge.tick!(by: @duo.judge, achieved: true) }.reason

    finish_current_race(@game)
    assert_equal :race_not_running, assert_raises(FlowError) { @fil_rouge.reload.tick!(by: @duo.judge, achieved: true) }.reason
  end

  test "une tâche ne compte que si elle est cochée et validée" do
    assert_not @fil_rouge.counts?
    @fil_rouge.update!(achieved: true)
    assert_not @fil_rouge.counts?
    @fil_rouge.update!(decision: "validated")
    assert @fil_rouge.counts?
    @fil_rouge.update!(decision: "rejected")
    assert_not @fil_rouge.counts?
  end

  test "un seul check par type, duo et course" do
    assert_raises(ActiveRecord::RecordNotUnique) { @race.checks.create!(duo: @duo, kind: "fil_rouge", catalog_item: @duo.fil_rouge_item) }
  end

  test "un type de check inconnu est invalide" do
    assert_not @race.checks.new(duo: @duo, kind: "inconnu", catalog_item: @duo.fil_rouge_item).valid?
  end

  test "fil rouge et tâche secrète ne sont visibles que du duo, pas des autres joueurs ni du MJ" do
    outsider = @cup.duos.last.pilot
    master = @cup.game_master
    others = [ outsider, master ].reject { |player| @duo.member?(player) }

    [ @fil_rouge, @secret ].each do |check|
      assert check.visible_to?(@duo.pilot)
      assert check.visible_to?(@duo.judge)
      others.each { |player| assert_not check.visible_to?(player), "#{check.kind} ne doit pas être visible de #{player.nickname}" }
    end
  end

  test "une action spéciale devient publique une fois réalisée et validée, visible du MJ dès qu'elle est cochée" do
    outsider = @cup.duos.last.pilot
    master = @cup.game_master
    assert_not @special.visible_to?(outsider)
    assert_not @duo.special_action_visible_to?(outsider)

    @special.update!(achieved: true)
    assert @special.visible_to?(master) || @duo.member?(master)
    assert_not @special.visible_to?(outsider)

    @special.update!(decision: "validated")
    assert @special.visible_to?(outsider)
    assert @duo.special_action_visible_to?(outsider)
    assert @duo.special_action_public?
  end
end
