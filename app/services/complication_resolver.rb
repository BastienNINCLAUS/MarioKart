# Points de position d'une course après application de la complication (Rules Collections/complications.md).
# Les complications "manuelles" ne changent rien ici : le MJ annule les points des fautifs (position_points_cancelled).
class ComplicationResolver
  AUTO_KEYS = %w[les_amoureux les_rivaux dernier_couronne podium_inverse].freeze
  MANUAL_KEYS = %w[pas_d_objets_offensifs objet_unique].freeze
  KEYS = (AUTO_KEYS + MANUAL_KEYS).freeze

  # positions : { duo_id => place } ; targets : duos ciblés ; base_points : { place => points }.
  # Retourne { duo_id => points de position }.
  def self.call(key:, positions:, targets:, base_points:)
    raise ArgumentError, "complication inconnue : #{key}" unless KEYS.include?(key)

    base = positions.transform_values { |place| base_points.fetch(place) }
    return base if MANUAL_KEYS.include?(key)

    send(key, base, positions, targets, base_points)
  end

  def self.les_amoureux(base, positions, targets, _base_points)
    first, second = targets
    return base if (positions.fetch(first) - positions.fetch(second)).abs <= 1

    base.merge(first => 0, second => 0)
  end

  def self.les_rivaux(base, positions, targets, _base_points)
    winner, loser = targets.sort_by { |duo_id| positions.fetch(duo_id) }
    base.merge(winner => base.fetch(winner) + base.fetch(loser))
  end

  def self.dernier_couronne(base, positions, _targets, _base_points)
    last = positions.max_by { |_duo_id, place| place }.first
    base.merge(last => base.fetch(last) * 2)
  end

  def self.podium_inverse(_base, positions, _targets, base_points)
    positions.transform_values { |place| base_points.fetch(positions.size - place + 1) }
  end

  private_class_method :les_amoureux, :les_rivaux, :dernier_couronne, :podium_inverse
end
