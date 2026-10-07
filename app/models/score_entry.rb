class ScoreEntry < ApplicationRecord
  KINDS = %w[position fil_rouge secret_task special_action].freeze

  belongs_to :game
  belongs_to :cup
  belongs_to :race
  belongs_to :player
  belongs_to :check, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :points, numericality: { only_integer: true }
end
