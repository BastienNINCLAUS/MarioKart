class Player < ApplicationRecord
  NICKNAME_MAX_LENGTH = 20

  belongs_to :game
  belongs_to :replaces, class_name: "Player", optional: true
  has_one :replacement, class_name: "Player", foreign_key: :replaces_id, inverse_of: :replaces, dependent: :nullify

  has_secure_token :session_token

  enum :status, { connected: "connected", abandoned: "abandoned" }, default: :connected

  normalizes :nickname, with: ->(nickname) { nickname.squish }

  validates :nickname, presence: true, length: { maximum: NICKNAME_MAX_LENGTH },
                       uniqueness: { scope: :game_id, case_sensitive: false }
  validate :game_accepts_new_players, on: :create

  after_create_commit { game.broadcast_refresh }

  def host?
    game.host_id == id
  end

  private

  # En partie lancée, seul un joueur qui prend le siège d'un joueur ayant abandonné peut arriver.
  def game_accepts_new_players
    return unless game

    if game.lobby?
      errors.add(:base, :game_full) if game.players.count >= Game::MAX_PLAYERS
    elsif !(game.in_progress? && replaces&.abandoned? && replaces.game_id == game_id)
      errors.add(:base, :game_started)
    end
  end
end
