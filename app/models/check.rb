class Check < ApplicationRecord
  # Ce que le MJ voit des tâches cochées est "à définir plus tard" (rules.md §4) : par défaut, pas les tâches secrètes.
  MASTER_SEES_SECRET_TASKS = false

  belongs_to :race
  belongs_to :duo
  belongs_to :catalog_item
  has_one :dispute, dependent: :destroy

  enum :kind, { fil_rouge: "fil_rouge", secret_task: "secret_task", special_action: "special_action" }, validate: true
  enum :decision, { pending: "pending", validated: "validated", rejected: "rejected" }, default: :pending, prefix: true

  after_update_commit -> { race.cup.game.broadcast_refresh }

  def tick!(by:, achieved:)
    raise FlowError, :not_judge unless by == duo.judge
    raise FlowError, :race_not_running unless race.reload.running?

    update!(achieved: achieved)
  end

  # Le duo conteste une tâche cochée que le MJ a refusée ; le MJ tranchera ou lancera un vote.
  def contest!(by:)
    raise FlowError, :not_duo_member unless duo.member?(by)
    raise FlowError, :not_contestable unless achieved? && decision_rejected? && !contested?

    transaction do
      update!(contested: true)
      create_dispute!(opened_by: by)
    end
  end

  # Une tâche cochée et validée rapporte des points seulement si le juge l'a cochée et que le MJ l'a validée.
  def counts?
    achieved? && decision_validated?
  end

  def points
    catalog_item.points
  end

  # Le contenu est réservé au duo ; une action spéciale devient publique une fois réalisée et validée.
  # Une tâche contestée est dévoilée à tous : les votants doivent savoir sur quoi ils se prononcent.
  def visible_to?(player)
    return true if contested? || duo.member?(player)
    return true if special_action? && counts?

    player == race.cup.game_master && (MASTER_SEES_SECRET_TASKS || (special_action? && achieved?))
  end
end
