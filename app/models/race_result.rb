class RaceResult < ApplicationRecord
  belongs_to :race
  belongs_to :duo
  # Pilote au moment de la course : un remplaçant ne récupère jamais les points d'une course déjà jouée.
  belongs_to :pilot, class_name: "Player", optional: true

  validates :position, numericality: { only_integer: true, greater_than: 0 }
end
