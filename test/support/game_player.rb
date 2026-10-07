# Fait avancer une partie réelle pour les tests de déroulement (nécessite load_catalog).
module GamePlayer
  # Chaque juge choisit un personnage, puis le MJ lance la coupe en préparation.
  def start_current_cup(game, random: seeded_random)
    cup = game.current_cup
    cup.duos.each_with_index { |duo, index| duo.update!(character: Characters::ALL[index]) }
    cup.start!(by: cup.game_master, random: random)
    cup.reload
  end

  # Lance la course en cours puis la termine. order : duos du premier au dernier (par défaut l'ordre des duos) ;
  # tick : checks que les juges cochent ; rejected : checks refusés par le MJ ; cancelled : duos dont les points sont annulés.
  def finish_current_race(game, order: nil, tick: [], rejected: [], cancelled: [], random: seeded_random)
    cup = game.current_cup
    race = cup.current_race
    master = cup.game_master
    race.start!(by: master)
    tick.each { |check| check.tick!(by: check.duo.judge, achieved: true) }
    ordered = order || cup.duos.to_a
    race.finish!(
      by: master, positions: ordered.each_with_index.to_h { |duo, index| [ duo.id, index + 1 ] },
      rejected_check_ids: rejected.map(&:id), cancelled_duo_ids: cancelled.map(&:id), random: random
    )
    race
  end

  # Joue la partie jusqu'au bout sans rien cocher, dans l'ordre des duos.
  def play_whole_game(game, random: seeded_random)
    while game.reload.in_progress?
      start_current_cup(game, random: random)
      Cup::RACES_COUNT.times { finish_current_race(game, random: random) }
    end
    game
  end
end
