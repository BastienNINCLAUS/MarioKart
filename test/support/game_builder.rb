# Construit des parties réelles via les modèles, sans passer par l'interface.
module GameBuilder
  # Retourne la partie ; game.host est l'hôte, les autres joueurs sont "Joueur 2", "Joueur 3"…
  # Une partie lancée a sa première coupe en préparation (tirage seedé, donc reproductible).
  def build_game(players: Game::MIN_PLAYERS, started: false, rotate_game_master: true, cups_count: nil, random: nil)
    game = Game.create_with_host!(nickname: "Hôte", rotate_game_master: rotate_game_master)
    (2..players).each { |index| game.players.create!(nickname: "Joueur #{index}") }
    game.start!(by: game.host, cups_count: cups_count, random: random || seeded_random) if started
    game
  end
end
