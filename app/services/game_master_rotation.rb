# Maître du jeu d'une coupe : tour à tour dans l'ordre de l'anneau (hôte en premier), sinon toujours l'hôte.
class GameMasterRotation
  def self.call(ring:, rotate:, cup_index:)
    rotate ? ring[cup_index % ring.size] : ring.first
  end
end
