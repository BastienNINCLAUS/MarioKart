# Classement individuel (rules.md §8). Départage : actions spéciales, puis tâches secrètes,
# puis meilleur classement de coupe (calculé en interne). Les ex æquo partagent le même rang.
class Ranking
  Entry = Data.define(:player, :rank, :points, :special_actions, :secret_tasks, :cup_ranks)

  # players : ordre d'affichage en cas d'égalité parfaite ; cup_points : { cup => { player => points } }.
  def self.call(players:, points:, special_actions:, secret_tasks:, cup_points:)
    cup_ranks = cup_ranks_by_player(players, cup_points)
    stats = players.map do |player|
      Entry.new(player: player, rank: nil, points: points.fetch(player, 0), special_actions: special_actions.fetch(player, 0),
                secret_tasks: secret_tasks.fetch(player, 0), cup_ranks: cup_ranks.fetch(player).sort)
    end

    sorted = stats.sort_by.with_index { |entry, index| [ sort_key(entry), index ] }
    sorted.map { |entry| entry.with(rank: 1 + sorted.count { |other| (sort_key(other) <=> sort_key(entry)).negative? }) }
  end

  def self.sort_key(entry)
    [ -entry.points, -entry.special_actions, -entry.secret_tasks, entry.cup_ranks ]
  end

  # Rang de chaque joueur dans chaque coupe (classement à égalité de points : rang partagé).
  def self.cup_ranks_by_player(players, cup_points)
    ranks = players.index_with { [] }
    cup_points.each_value do |scores|
      totals = players.index_with { |player| scores.fetch(player, 0) }
      players.each { |player| ranks[player] << (1 + totals.values.count { |value| value > totals[player] }) }
    end
    ranks
  end

  private_class_method :sort_key, :cup_ranks_by_player
end
