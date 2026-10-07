class Race < ApplicationRecord
  belongs_to :cup
  belongs_to :complication_item, class_name: "CatalogItem"
  has_many :checks, -> { order(:id) }, dependent: :destroy
  has_many :race_results, dependent: :destroy
  has_many :score_entries, dependent: :destroy

  enum :status, { pending: "pending", running: "running", finished: "finished" }, default: :pending

  validates :position, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :cup_id }

  after_commit -> { cup.game.broadcast_refresh }

  def start!(by:)
    raise FlowError, :not_game_master unless by == cup.game_master
    raise FlowError, :not_pending unless pending?

    running!
  end

  # positions : { duo_id => place }. Les tâches cochées sont validées sauf celles listées dans rejected_check_ids.
  def finish!(by:, positions:, rejected_check_ids: [], cancelled_duo_ids: [], random: Random.new)
    raise FlowError, :not_game_master unless by == cup.game_master
    raise FlowError, :not_running unless running?

    duo_ids = cup.duos.map(&:id)
    pilots = cup.duos.index_by(&:id).transform_values(&:pilot_id)
    positions = positions.to_h.transform_keys(&:to_i).transform_values { |place| Integer(place, exception: false) }
    valid_positions = positions.keys.sort == duo_ids.sort && positions.values.all?(Integer) &&
                      positions.values.sort == (1..duo_ids.size).to_a
    raise FlowError, :invalid_positions unless valid_positions

    cancelled = cancelled_duo_ids.map(&:to_i) & duo_ids
    raise FlowError, :cancellation_not_allowed if cancelled.any? && complication_item.params["calculation"] != "manual"

    transaction do
      positions.each do |duo_id, place|
        race_results.create!(duo_id: duo_id, position: place, pilot_id: pilots.fetch(duo_id),
                             position_points_cancelled: cancelled.include?(duo_id))
      end
      rejected = rejected_check_ids.map(&:to_i)
      checks.select(&:achieved?).each { |check| check.update!(decision: rejected.include?(check.id) ? "rejected" : "validated") }
      finished!
      RaceScorer.call(self)
      cup.advance!(random: random)
    end
  end

  def targeted_duos
    cup.duos.select { |duo| target_duo_ids.include?(duo.id) }
  end

  # Publique : tout le monde. Secrète : le MJ et les duos concernés (tous les duos si aucune cible).
  def complication_visible_to?(player)
    return true if complication_item.visibility == "public" || player == cup.game_master

    concerned = target_duo_ids.empty? ? cup.duos : targeted_duos
    concerned.any? { |duo| duo.member?(player) }
  end

  def result_for(duo)
    race_results.find { |result| result.duo_id == duo.id }
  end
end
