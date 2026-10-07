require "test_helper"

# Les diffusions Turbo sont publiques (le nom du flux est lisible dans la page) : elles ne doivent jamais
# contenir de contenu, seulement l'ordre de recharger la page, qui est rendue pour chaque joueur.
class BroadcastPrivacyTest < ActiveSupport::TestCase
  setup do
    load_catalog
    @game = build_game(players: 6, started: true, cups_count: 2)
  end

  def play_everything_that_can_happen
    cup = start_current_cup(@game)
    master = cup.game_master
    duo = cup.duos.find { |candidate| candidate.judge != master }
    race = cup.current_race
    check = race.checks.find { |candidate| candidate.duo_id == duo.id && candidate.fil_rouge? }
    finish_current_race(@game, tick: [ check ], rejected: [ check ])
    dispute = check.reload.contest!(by: duo.pilot)
    dispute.start_vote!(by: master)
    @game.players.where.not(id: [ duo.pilot_id, duo.judge_id, master.id ]).find_each { |voter| dispute.vote!(by: voter, approve: true) }
    ReplacementService.abandon!(game: @game, by: master, player: duo.pilot)
    ReplacementService.fill_seat!(game: @game, nickname: "Relève")
    3.times { finish_current_race(@game) }
    play_whole_game(@game)
  end

  test "toutes les diffusions d'une partie complète sont de simples ordres de rechargement sans contenu" do
    broadcasts = capture_turbo_stream_broadcasts(@game) { play_everything_that_can_happen }

    assert_operator broadcasts.size, :>, 20
    assert broadcasts.all? { |element| element["action"] == "refresh" }, "seul l'action refresh est autorisée"
    assert broadcasts.none? { |element| element.element_children.any? || element.text.strip.present? }, "une diffusion contient du contenu"
  end

  test "aucune diffusion ne contient un texte du catalogue ni un pseudo" do
    broadcasts = capture_turbo_stream_broadcasts(@game) { play_everything_that_can_happen }
    forbidden = CatalogItem.pluck(:name, :description).flatten + @game.players.pluck(:nickname)

    payload = broadcasts.map(&:to_s).join
    forbidden.each { |text| assert_not_includes payload, text }
  end

  test "le code source ne diffuse que des rechargements, sur le seul flux de la partie" do
    sources = Dir[Rails.root.join("app/**/*.{rb,erb}")].to_h { |file| [ file, File.read(file) ] }
    content_broadcasts = /broadcast_(replace|append|prepend|update|remove|action|before|after)|broadcasts_to|\bbroadcasts\b|Turbo::StreamsChannel\.broadcast_(?!refresh)/
    offenders = sources.select { |_file, source| source.match?(content_broadcasts) }.keys

    assert_empty offenders, "diffusion de contenu interdite : #{offenders}"
    streams = sources.select { |file, source| file.end_with?(".erb") && source.include?("turbo_stream_from") }
    assert_equal [ "show.html.erb" ], streams.keys.map { |file| File.basename(file) }
    assert_equal 1, streams.values.first.scan("turbo_stream_from").size
  end
end
