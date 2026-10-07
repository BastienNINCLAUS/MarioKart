class Vote < ApplicationRecord
  belongs_to :dispute
  belongs_to :player

  validates :player_id, uniqueness: { scope: :dispute_id }

  after_create_commit { dispute.game.broadcast_refresh }
end
