# Joue une partie complète avec un comportement de joueurs scripté mais reproductible (deux Random seedés :
# l'un pour les tirages de l'application, l'autre pour les choix des joueurs). Nécessite load_catalog.
class GameSimulator
  TICK_PROBABILITY = { "fil_rouge" => 0.6, "secret_task" => 0.4, "special_action" => 0.25 }.freeze
  REJECT_PROBABILITY = 0.25
  CANCEL_PROBABILITY = 0.3
  CONTEST_PROBABILITY = 0.6
  SWAP_PROBABILITY = 0.3

  attr_reader :game, :swaps_applied

  # replace_a_player : après la première course, un pilote abandonne et "Relève" prend sa place.
  # swap_probability : chance que le MJ échange deux joueurs avant une coupe (0 pour garder le tirage de l'appli).
  def initialize(game, draws:, script:, replace_a_player: true, swap_probability: SWAP_PROBABILITY)
    @game = game
    @draws = draws
    @script = script
    @replace_a_player = replace_a_player
    @swap_probability = swap_probability
    @swaps_applied = 0
  end

  def play!
    play_cup(game.current_cup) until game.reload.finished?
    self
  end

  # Résumé complet et sans identifiants de la partie, utilisé pour figer les résultats attendus.
  def snapshot
    game.reload
    {
      "players" => game.players.where(replaces_id: nil).count,
      "cups_count" => game.cups_count,
      "rotate_game_master" => game.rotate_game_master,
      "status" => game.status,
      "cups" => game.cups.map { |cup| cup_snapshot(cup) },
      "disputes" => game.disputes.order(:id).map { |dispute| dispute_snapshot(dispute) },
      "abandoned" => game.players.abandoned.order(:id).map(&:nickname),
      "ranking" => ranking_snapshot
    }
  end

  private

  def play_cup(cup)
    swap_two_players(cup)
    cup.reload
    characters = Characters::ALL.sample(cup.duos.size, random: @script)
    cup.duos.each_with_index { |duo, index| duo.update!(character: characters[index]) }
    cup.start!(by: cup.game_master, random: @draws)
    Cup::RACES_COUNT.times { play_race }
  end

  def swap_two_players(cup)
    return unless @script.rand < @swap_probability

    first, second = cup.duos.flat_map { |duo| [ duo.pilot, duo.judge ] }.sample(2, random: @script)
    RoleAdjuster.swap!(cup: cup, player: first, other: second)
    @swaps_applied += 1
  rescue RoleAdjuster::Invalid
    nil
  end

  def play_race
    cup = game.current_cup
    race = cup.current_race
    master = cup.game_master
    race.start!(by: master)
    tick_checks(race)

    achieved = Check.where(race: race).order(:id).select(&:achieved?)
    rejected = achieved.select { @script.rand < REJECT_PROBABILITY }
    cancelled = race.complication_item.params["calculation"] == "manual" ? cup.duos.select { @script.rand < CANCEL_PROBABILITY } : []
    order = cup.duos.to_a.shuffle(random: @script)

    race.reload.finish!(
      by: master, positions: order.each_with_index.to_h { |duo, index| [ duo.id, index + 1 ] },
      rejected_check_ids: rejected.map(&:id), cancelled_duo_ids: cancelled.map(&:id), random: @draws
    )
    rejected.each { |check| contest(check.reload) }
    replace_a_player(cup)
  end

  def tick_checks(race)
    Check.where(race: race).order(:id).includes(:duo).each do |check|
      check.tick!(by: check.duo.judge, achieved: true) if @script.rand < TICK_PROBABILITY.fetch(check.kind)
    end
  end

  def contest(check)
    return unless @script.rand < CONTEST_PROBABILITY

    dispute = check.contest!(by: [ check.duo.pilot, check.duo.judge ].sample(random: @script))
    master = dispute.game_master
    case @script.rand(3)
    when 0 then dispute.decide!(by: master, approve: true)
    when 1 then dispute.decide!(by: master, approve: false)
    else vote(dispute, master)
    end
  end

  def vote(dispute, master)
    dispute.start_vote!(by: master)
    dispute.voters.to_a.each { |voter| dispute.vote!(by: voter, approve: @script.rand < 0.5) }
    dispute.reload.decide!(by: master, approve: @script.rand < 0.5) if dispute.status_tied?
  rescue FlowError => error
    raise unless error.reason == :no_voters

    dispute.decide!(by: master, approve: false)
  end

  def replace_a_player(cup)
    return unless @replace_a_player && !@replaced

    @replaced = true
    cup = Cup.find(cup.id)
    leaver = cup.duos.map(&:pilot).find { |pilot| pilot != game.host && pilot != cup.game_master }
    ReplacementService.abandon!(game: game, by: cup.game_master, player: leaver)
    ReplacementService.fill_seat!(game: game, nickname: "Relève")
  end

  def cup_snapshot(cup)
    {
      "position" => cup.position,
      "game_master" => cup.game_master.nickname,
      "duos" => cup.duos.map { |duo| [ duo.pilot.nickname, duo.judge.nickname, duo.character, duo.fil_rouge_item.key, duo.special_action_item.key ].join(" / ") },
      "races" => cup.races.map { |race| race_snapshot(race) }
    }
  end

  def race_snapshot(race)
    results = race.race_results.includes(:pilot).sort_by(&:position)
    points = race.score_entries.group(:player_id).sum(:points)
    pilot_by_duo = results.to_h { |result| [ result.duo_id, result.pilot.nickname ] }

    {
      "position" => race.position,
      "complication" => race.complication_item.key,
      "targets" => race.target_duo_ids.map { |duo_id| pilot_by_duo.fetch(duo_id) },
      "results" => results.map { |result| "#{result.position}. #{result.pilot.nickname} #{points.fetch(result.pilot_id, 0)} pts#{' (annulé)' if result.position_points_cancelled}" },
      "tasks" => race.checks.select(&:achieved?).map do |check|
        "#{pilot_by_duo.fetch(check.duo_id)} #{check.kind} #{check.catalog_item.key} #{check.decision}#{' contesté' if check.contested?}"
      end
    }
  end

  def dispute_snapshot(dispute)
    check = dispute.check
    race = check.race
    votes = dispute.votes
    "c#{race.cup.position}r#{race.position} #{check.catalog_item.key} par #{dispute.opened_by.nickname} : #{dispute.outcome} " \
      "(#{votes.count(&:approve)} pour, #{votes.count { |vote| !vote.approve }} contre)"
  end

  def ranking_snapshot
    names = game.players.index_by(&:id)
    game.ranking.map do |entry|
      "#{entry.rank}. #{names[entry.player].nickname} #{entry.points} pts (#{entry.special_actions} actions spéciales, #{entry.secret_tasks} tâches secrètes)"
    end
  end
end
