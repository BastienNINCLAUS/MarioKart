# Points d'une course par duo : position (après complication) + tâches validées (rules.md §7, §8).
# Les valeurs de position sont provisoires : l'équilibrage est reporté après le POC.
class ScoreCalculator
  POSITION_POINTS_STEP = 2
  CHECK_KINDS = %w[fil_rouge secret_task special_action].freeze

  Breakdown = Data.define(:position, :fil_rouge, :secret_task, :special_action) do
    def total
      position + fil_rouge + secret_task + special_action
    end
  end

  # Points de la place p pour n duos : le premier reçoit n * step, le dernier step.
  def self.position_points(duos_count)
    (1..duos_count).to_h { |place| [ place, (duos_count - place + 1) * POSITION_POINTS_STEP ] }
  end

  # positions : { duo_id => place } ; cancelled : duos dont les points de position sont annulés ;
  # achievements : { duo_id => { kind => points } } pour les tâches cochées ET validées.
  def self.call(positions:, complication_key:, targets:, cancelled:, achievements:)
    position_points = ComplicationResolver.call(
      key: complication_key, positions: positions, targets: targets, base_points: position_points(positions.size)
    )

    positions.keys.index_with do |duo_id|
      earned = achievements.fetch(duo_id, {})
      Breakdown.new(
        position: cancelled.include?(duo_id) ? 0 : position_points.fetch(duo_id),
        fil_rouge: earned.fetch("fil_rouge", 0),
        secret_task: earned.fetch("secret_task", 0),
        special_action: earned.fetch("special_action", 0)
      )
    end
  end
end
