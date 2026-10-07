class Duo < ApplicationRecord
  belongs_to :cup
  belongs_to :pilot, class_name: "Player"
  belongs_to :judge, class_name: "Player"
  belongs_to :fil_rouge_item, class_name: "CatalogItem", optional: true
  belongs_to :special_action_item, class_name: "CatalogItem", optional: true

  validates :character, inclusion: { in: Characters::ALL }, uniqueness: { scope: :cup_id }, allow_nil: true
  validate :roles_are_coherent

  after_update_commit -> { cup.game.broadcast_refresh }

  def member?(player)
    player.present? && [ pilot_id, judge_id ].include?(player.id)
  end

  # Une action spéciale devient publique dès qu'elle a été réalisée et validée au moins une fois.
  def special_action_public?
    Check.special_action.where(duo_id: id, achieved: true, decision: "validated").exists?
  end

  def special_action_visible_to?(player)
    member?(player) || special_action_public?
  end

  private

  def roles_are_coherent
    return unless cup && pilot && judge

    errors.add(:base, :same_player) if pilot == judge
    errors.add(:base, :game_master_cannot_pilot) if pilot_id == cup.game_master_id
    errors.add(:base, :foreign_player) unless [ pilot, judge ].all? { |player| player.game_id == cup.game_id }
  end
end
