# Nombre de coupes d'une partie (rules.md §4 : cycle réduit par défaut, le MJ peut l'augmenter).
class CupCountCalculator
  DEFAULT = 2
  MAX = 12

  def initialize(players_count)
    @players_count = players_count
  end

  def default
    DEFAULT
  end

  # Nombre de coupes au bout duquel chaque joueur a piloté exactement autant de fois.
  def full_cycle
    @players_count.even? ? 2 : @players_count
  end

  def valid?(cups)
    cups.is_a?(Integer) && cups.between?(DEFAULT, MAX)
  end

  # Écart maximal de nombre de pilotages entre deux joueurs.
  def fairness_gap(cups)
    (cups % full_cycle).zero? ? 0 : 1
  end
end
