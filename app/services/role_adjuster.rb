# Ajustement des rôles par le MJ avant la coupe : échange les places de deux joueurs (rules.md §4).
class RoleAdjuster
  class Invalid < StandardError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super(reason.to_s)
    end
  end

  def self.swap!(cup:, player:, other:)
    new(cup).swap!(player, other)
  end

  def initialize(cup)
    @cup = cup
    @duos = cup.duos.reload.to_a
  end

  def swap!(player, other)
    raise Invalid, :not_setup unless @cup.setup?
    raise Invalid, :same_player if player == other

    seat = locate(player)
    other_seat = locate(other)
    raise Invalid, :game_master_cannot_pilot if forbidden?(player, other_seat) || forbidden?(other, seat)

    Duo.transaction do
      seat.first.public_send("#{seat.last}=", other)
      other_seat.first.public_send("#{other_seat.last}=", player)
      [ seat.first, other_seat.first ].uniq.each { |duo| save_without_character(duo) }
    end
  end

  private

  def locate(player)
    duo = @duos.find { |candidate| [ candidate.pilot_id, candidate.judge_id ].include?(player.id) }
    raise Invalid, :not_in_duo unless duo

    [ duo, duo.pilot_id == player.id ? :pilot : :judge ]
  end

  def forbidden?(player, destination)
    player.id == @cup.game_master_id && destination.last == :pilot
  end

  def save_without_character(duo)
    duo.character = nil if duo.pilot_id_changed?
    duo.save!
  end
end
