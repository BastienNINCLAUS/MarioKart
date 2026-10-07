# Hasard injectable : les services reçoivent un Random seedé pour des tirages reproductibles.
module SeededRandom
  DEFAULT_SEED = 20_260_101

  def seeded_random(seed = DEFAULT_SEED)
    Random.new(seed)
  end

  # Exécute le bloc pour chaque graine afin de tester des invariants sur de nombreux tirages.
  def with_seeds(count = 50)
    count.times { |seed| yield Random.new(seed), seed }
  end
end
