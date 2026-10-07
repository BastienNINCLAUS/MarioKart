# Tirage au sort d'éléments du catalogue, sans doublon, avec un Random injecté.
class CatalogDrawer
  class NotEnoughItems < StandardError; end

  # exclude : éléments à éviter (ignorés s'il n'en reste pas assez pour tirer `count` éléments).
  def self.call(kind:, count:, exclude: [], random: Random.new)
    pool = CatalogItem.where(kind: kind).order(:id).to_a
    available = pool - exclude
    available = pool if available.size < count
    raise NotEnoughItems, "#{kind} : #{available.size} élément(s) pour #{count} tirage(s)" if available.size < count

    available.sample(count, random: random)
  end
end
