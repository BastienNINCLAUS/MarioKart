class Dispute < ApplicationRecord
  belongs_to :check
  belongs_to :opened_by, class_name: "Player"
  has_many :votes, dependent: :destroy

  # Ouverte : le MJ tranche ou lance un vote. En vote : égalité -> "tied" et le MJ tranche (rules.md §9).
  enum :status, { open: "open", voting: "voting", tied: "tied", resolved: "resolved" }, default: :open, prefix: :status

  validates :check_id, uniqueness: true

  after_commit -> { game.broadcast_refresh }

  delegate :duo, :race, to: :check

  def cup
    race.cup
  end

  def game
    cup.game
  end

  def game_master
    cup.game_master
  end

  # Le MJ de la coupe tranche ; l'hôte, administrateur permanent, peut aussi corriger.
  def authority?(player)
    player.present? && (player == game_master || player.id == game.host_id)
  end

  # Tous les joueurs présents sauf le duo concerné ; le MJ ne vote pas, il départage.
  def voters
    game.players.connected.where.not(id: [ duo.pilot_id, duo.judge_id, game_master.id ]).order(:id)
  end

  def start_vote!(by:)
    raise FlowError, :not_authority unless authority?(by)
    raise FlowError, :not_open unless status_open?
    raise FlowError, :no_voters if voters.none?

    status_voting!
  end

  def vote!(by:, approve:)
    raise FlowError, :not_voting unless status_voting?
    raise FlowError, :not_voter unless by.present? && voters.exists?(by.id)
    raise FlowError, :already_voted if votes.exists?(player_id: by.id)

    transaction do
      votes.create!(player: by, approve: approve)
      tally! if votes.count >= voters.count
    end
  end

  # Le MJ clôt le vote avec les voix déjà exprimées.
  def close_vote!(by:)
    raise FlowError, :not_authority unless authority?(by)
    raise FlowError, :not_voting unless status_voting?

    tally!
  end

  def decide!(by:, approve:)
    raise FlowError, :not_authority unless authority?(by)
    raise FlowError, :not_decidable unless status_open? || status_tied?

    resolve!(approve)
  end

  def validated?
    status_resolved? && outcome == "validated"
  end

  private

  def tally!
    approvals = votes.where(approve: true).count
    rejections = votes.where(approve: false).count
    approvals == rejections ? status_tied! : resolve!(approvals > rejections)
  end

  def resolve!(approve)
    transaction do
      update!(status: :resolved, outcome: approve ? "validated" : "rejected")
      if approve
        check.update!(decision: "validated")
        RaceScorer.call(race)
      end
    end
  end
end
