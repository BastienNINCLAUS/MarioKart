# Abandon et remplacement (rules.md §13) : le MJ décide de l'abandon, le joueur garde ses points,
# et une personne disponible peut rejoindre avec le code pour reprendre son siège.
class ReplacementService
  # Le MJ de la coupe en cours ou l'hôte marque un joueur comme ayant abandonné.
  def self.abandon!(game:, by:, player:)
    authorize!(game, by)
    raise FlowError, :cannot_abandon_host if player.id == game.host_id
    raise FlowError, :already_abandoned unless player.connected?

    player.abandoned!
    game.broadcast_refresh
  end

  # Le joueur est revenu avant que quelqu'un prenne sa place.
  def self.reinstate!(game:, by:, player:)
    authorize!(game, by)
    raise FlowError, :seat_taken if Player.exists?(replaces_id: player.id)
    raise FlowError, :not_abandoned unless player.abandoned?

    player.connected!
    game.broadcast_refresh
  end

  # Une nouvelle personne prend le plus ancien siège libre : coupe en cours et coupes suivantes.
  # Lève ActiveRecord::RecordInvalid si le pseudo est refusé.
  def self.fill_seat!(game:, nickname:)
    abandoned = game.open_seats.first
    raise FlowError, :no_open_seat unless abandoned

    Player.transaction do
      replacement = game.players.create!(nickname: nickname, replaces: abandoned)
      take_over_current_cup(game.current_cup, abandoned, replacement)
      replacement
    end
  end

  def self.take_over_current_cup(cup, abandoned, replacement)
    return if cup.nil? || cup.finished?

    cup.update!(game_master: replacement) if cup.game_master_id == abandoned.id
    cup.duos.each do |duo|
      duo.pilot = replacement if duo.pilot_id == abandoned.id
      duo.judge = replacement if duo.judge_id == abandoned.id
      duo.save! if duo.changed?
    end
  end

  def self.authorize!(game, by)
    raise FlowError, :not_in_progress unless game.in_progress?

    allowed = by.present? && (by.id == game.host_id || by == game.current_cup&.game_master)
    raise FlowError, :not_authority unless allowed
  end

  private_class_method :take_over_current_cup, :authorize!
end
