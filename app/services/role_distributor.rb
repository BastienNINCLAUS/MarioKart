# Répartit les rôles d'une coupe (rules.md §4) : MJ, pilotes, juges et duos pilote/juge.
#
# Pair : N/2 pilotes, N/2 juges dont le MJ. Impair : (N-1)/2 pilotes, (N-1)/2 juges, MJ qui ne joue pas.
# Les pilotes sont les joueurs les moins souvent pilotes ; à égalité, ceux qui auront le moins
# d'occasions de piloter dans les coupes restantes passent d'abord, puis le hasard (injecté) départage.
class RoleDistributor
  Plan = Data.define(:game_master, :pairs)

  def self.call(**arguments)
    new(**arguments).call
  end

  # ring : joueurs dans l'ordre de rotation du MJ ; pilot_counts : pilotages déjà effectués par joueur.
  def initialize(ring:, rotate:, cups_count:, cup_index:, pilot_counts:, random: Random.new)
    @ring = ring
    @rotate = rotate
    @cups_count = cups_count
    @cup_index = cup_index
    @pilot_counts = pilot_counts
    @random = random
  end

  def call
    game_master = master_for(@cup_index)
    candidates = @ring - [ game_master ]
    pilots = candidates.sort_by { |player| priority(player) }.first(@ring.size / 2).sort_by { |player| @ring.index(player) }
    judges = candidates - pilots
    judges << game_master if @ring.size.even?

    Plan.new(game_master: game_master, pairs: pilots.zip(judges.shuffle(random: @random)))
  end

  private

  def master_for(cup_index)
    GameMasterRotation.call(ring: @ring, rotate: @rotate, cup_index: cup_index)
  end

  def priority(player)
    [ @pilot_counts.fetch(player, 0), remaining_opportunities(player), @random.rand ]
  end

  def remaining_opportunities(player)
    ((@cup_index + 1)...@cups_count).count { |index| master_for(index) != player }
  end
end
