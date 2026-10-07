require "test_helper"

# rules.md §6 : lancement de coupe et de course, cases cochées par le juge, validation par le MJ, confidentialité.
class RacesFlowTest < ActionDispatch::IntegrationTest
  setup do
    load_catalog
    @game = build_game(players: 6, started: true, cups_count: 2)
    @cup = @game.current_cup
    @master = @cup.game_master
  end

  def prepare_cup
    @cup.duos.each_with_index { |duo, index| duo.update!(character: Characters::ALL[index]) }
  end

  def start_cup_and_race
    prepare_cup
    @cup.start!(by: @master, random: seeded_random)
    @race = @cup.current_race
  end

  def page_for(player)
    sign_in_as(player)
    get game_path(@game)
    response.body
  end

  test "le MJ lance la coupe quand tous les personnages sont choisis" do
    prepare_cup
    sign_in_as(@master)

    post start_game_cup_path(@game, @cup)

    assert_redirected_to game_path(@game)
    assert @cup.reload.in_progress?
    assert_equal 1, @cup.races.count
  end

  test "la coupe ne se lance pas sans personnages ni par un autre joueur" do
    sign_in_as(@master)
    post start_game_cup_path(@game, @cup)
    assert_equal I18n.t("flow_errors.characters_missing"), flash[:alert]
    assert @cup.reload.setup?

    prepare_cup
    sign_in_as(@cup.duos.first.pilot)
    post start_game_cup_path(@game, @cup)
    assert_equal I18n.t("cups.errors.not_game_master"), flash[:alert]
    assert @cup.reload.setup?
  end

  test "le bouton de lancement de coupe est réservé au MJ et désactivé tant que les personnages manquent" do
    sign_in_as(@master)
    get game_path(@game)
    assert_select "form[action='#{start_game_cup_path(@game, @cup)}'] button[disabled], form[action='#{start_game_cup_path(@game, @cup)}'] input[disabled]"

    prepare_cup
    get game_path(@game)
    assert_select "form[action='#{start_game_cup_path(@game, @cup)}'] [disabled]", false

    sign_in_as(@cup.duos.first.pilot)
    get game_path(@game)
    assert_select "form[action='#{start_game_cup_path(@game, @cup)}']", false
  end

  test "le MJ lance la course, les autres joueurs ne le peuvent pas" do
    start_cup_and_race
    sign_in_as(@cup.duos.map(&:pilot).find { |pilot| pilot != @master })
    post start_game_race_path(@game, @race)
    assert_equal I18n.t("flow_errors.not_game_master"), flash[:alert]
    assert @race.reload.pending?

    sign_in_as(@master)
    post start_game_race_path(@game, @race)
    assert @race.reload.running?
  end

  test "le juge coche les tâches de son duo pendant la course, pas les autres joueurs" do
    start_cup_and_race
    duo = @cup.duos.first
    check = @race.checks.find { |candidate| candidate.duo_id == duo.id && candidate.fil_rouge? }
    sign_in_as(duo.judge)
    patch game_check_path(@game, check), params: { achieved: true }
    assert_equal I18n.t("flow_errors.race_not_running"), flash[:alert]

    @race.start!(by: @master)
    patch game_check_path(@game, check), params: { achieved: true }
    assert check.reload.achieved?

    patch game_check_path(@game, check), params: { achieved: false }
    assert_not check.reload.achieved?

    sign_in_as(duo.pilot)
    patch game_check_path(@game, check), params: { achieved: true }
    assert_equal I18n.t("flow_errors.not_judge"), flash[:alert]
    assert_not check.reload.achieved?
  end

  test "un non-membre ne peut pas cocher" do
    start_cup_and_race
    check = @race.checks.first

    patch game_check_path(@game, check), params: { achieved: true }

    assert_redirected_to root_path(code: @game.code)
  end

  test "le MJ termine la course avec les places, les tâches cochées sont validées sauf refus" do
    start_cup_and_race
    @race.update!(complication_item: CatalogItem.find_by!(key: "objet_unique"), target_duo_ids: [])
    first, second, third = @cup.duos.to_a
    ticked = @race.checks.find { |check| check.duo_id == first.id && check.fil_rouge? }
    refused = @race.checks.find { |check| check.duo_id == second.id && check.secret_task? }
    @race.start!(by: @master)
    ticked.tick!(by: first.judge, achieved: true)
    refused.tick!(by: second.judge, achieved: true)
    sign_in_as(@master)

    post finish_game_race_path(@game, @race), params: {
      positions: { first.id => 2, second.id => 1, third.id => 3 }, rejected: [ refused.id ]
    }

    assert_redirected_to game_path(@game)
    assert @race.reload.finished?
    assert ticked.reload.decision_validated?
    assert refused.reload.decision_rejected?
    assert_equal 1, @race.race_results.find_by(duo: second).position
    assert_equal 2, @cup.reload.races.count
  end

  test "des places invalides sont refusées avec un message et la course reste en cours" do
    start_cup_and_race
    @race.start!(by: @master)
    sign_in_as(@master)

    post finish_game_race_path(@game, @race), params: { positions: @cup.duos.to_h { |duo| [ duo.id, 1 ] } }

    assert_equal I18n.t("flow_errors.invalid_positions"), flash[:alert]
    assert @race.reload.running?
  end

  test "le formulaire de fin de course n'apparaît que pour le MJ pendant la course" do
    start_cup_and_race
    sign_in_as(@master)
    get game_path(@game)
    assert_select "form[action='#{finish_game_race_path(@game, @race)}']", false
    assert_select "form[action='#{start_game_race_path(@game, @race)}']"

    @race.start!(by: @master)
    get game_path(@game)
    assert_select "form[action='#{finish_game_race_path(@game, @race)}'] select", @cup.duos.size

    sign_in_as(@cup.duos.map(&:pilot).find { |pilot| pilot != @master })
    get game_path(@game)
    assert_select "form[action='#{finish_game_race_path(@game, @race)}']", false
  end

  test "confidentialité : fil rouge, tâche secrète et action spéciale ne sont visibles que du duo" do
    start_cup_and_race
    duo = @cup.duos.find { |candidate| candidate.judge != @master }
    secret = @race.checks.find { |check| check.duo_id == duo.id && check.secret_task? }.catalog_item
    texts = [ duo.fil_rouge_item, duo.special_action_item, secret ].map { |item| CGI.escapeHTML(item.description) }
    outsiders = @cup.duos.reject { |other| other == duo }.map(&:pilot)

    [ duo.pilot, duo.judge ].each do |member|
      body = page_for(member)
      texts.each { |text| assert_includes body, text }
    end
    (outsiders + [ @master ]).each do |viewer|
      body = page_for(viewer)
      texts.each { |text| assert_not_includes body, text, "#{viewer.nickname} ne doit pas voir ce texte" }
    end
  end

  test "une action spéciale réalisée et validée devient publique" do
    start_cup_and_race
    duo = @cup.duos.find { |candidate| candidate.judge != @master }
    special = @race.checks.find { |check| check.duo_id == duo.id && check.special_action? }
    outsider = @cup.duos.find { |other| other != duo }.pilot
    assert_not_includes page_for(outsider), CGI.escapeHTML(duo.special_action_item.name)

    @race.start!(by: @master)
    special.tick!(by: duo.judge, achieved: true)
    @race.finish!(by: @master, positions: @cup.duos.each_with_index.to_h { |d, index| [ d.id, index + 1 ] })

    assert_includes page_for(outsider), CGI.escapeHTML(I18n.t("games.duos.special_action_done", name: duo.special_action_item.name))
  end

  test "le MJ ne voit pas le contenu des tâches secrètes cochées, mais voit qu'une tâche est cochée" do
    start_cup_and_race
    duo = @cup.duos.find { |candidate| candidate.judge != @master }
    check = @race.checks.find { |candidate| candidate.duo_id == duo.id && candidate.fil_rouge? }
    @race.start!(by: @master)
    check.tick!(by: duo.judge, achieved: true)

    body = page_for(@master)

    assert_includes body, I18n.t("games.race.ticked_task")
    assert_not_includes body, CGI.escapeHTML(check.catalog_item.name)
  end

  test "une complication secrète n'est visible que du MJ et des duos concernés" do
    start_cup_and_race
    first, second, third = @cup.duos.to_a
    rivals = CatalogItem.find_by!(key: "les_rivaux")
    @race.update!(complication_item: rivals, target_duo_ids: [ first.id, second.id ])
    outsider = third.pilot == @master ? third.judge : third.pilot

    assert_includes page_for(first.pilot), CGI.escapeHTML(rivals.description)
    assert_includes page_for(@master), CGI.escapeHTML(rivals.description)
    body = page_for(outsider)
    assert_not_includes body, CGI.escapeHTML(rivals.description)
    assert_includes body, I18n.t("games.race.secret_complication")
  end

  test "le classement est visible de tous et la partie terminée affiche le résultat final" do
    game = build_game(players: 4, started: true, cups_count: 2)
    play_whole_game(game)
    sign_in_as(game.host)

    get game_path(game)

    assert_select "h2", I18n.t("games.ranking.heading")
    assert_select "#ranking li", 4
    assert_select "p", I18n.t("games.show.finished")
  end
end
