# Enregistre (de façon idempotente) les points d'une course terminée : un seul pilote par duo, le juge ne marque rien.
class RaceScorer
  def self.call(race)
    new(race).call
  end

  def initialize(race)
    @race = race
  end

  def call
    ScoreEntry.transaction do
      @race.score_entries.delete_all
      breakdowns.each do |result, breakdown|
        record(result, "position", breakdown.position)
        counted_checks.fetch(result.duo_id, []).each { |check| record(result, check.kind, check.points, check) }
      end
    end
  end

  private

  def results
    @results ||= @race.race_results.includes(:pilot, duo: :pilot).to_a
  end

  def counted_checks
    @counted_checks ||= @race.checks.includes(:catalog_item).select(&:counts?).group_by(&:duo_id)
  end

  def breakdowns
    achievements = counted_checks.transform_values { |checks| checks.to_h { |check| [ check.kind, check.points ] } }
    computed = ScoreCalculator.call(
      positions: results.to_h { |result| [ result.duo_id, result.position ] },
      complication_key: @race.complication_item.key,
      targets: @race.target_duo_ids,
      cancelled: results.select(&:position_points_cancelled).map(&:duo_id),
      achievements: achievements
    )
    results.to_h { |result| [ result, computed.fetch(result.duo_id) ] }
  end

  def record(result, kind, points, check = nil)
    ScoreEntry.create!(game: @race.cup.game, cup: @race.cup, race: @race, player: result.pilot || result.duo.pilot,
                       check: check, kind: kind, points: points)
  end
end
