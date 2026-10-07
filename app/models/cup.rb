class Cup < ApplicationRecord
  RACES_COUNT = 4

  belongs_to :game
  belongs_to :game_master, class_name: "Player"
  has_many :duos, -> { order(:id) }, dependent: :destroy
  has_many :races, -> { order(:position) }, dependent: :destroy

  enum :status, { setup: "setup", in_progress: "in_progress", finished: "finished" }, default: :setup

  validates :position, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :game_id }

  # La première coupe est annoncée par le changement de statut de la partie.
  after_create_commit -> { game.broadcast_refresh }, unless: -> { position == 1 }

  def ready?
    duos.any? && duos.all? { |duo| duo.character.present? }
  end

  # Tire le fil rouge et l'action spéciale de chaque duo (sans doublon), puis prépare la première course.
  def start!(by:, random: Random.new)
    raise FlowError, :not_game_master unless by == game_master
    raise FlowError, :not_setup unless setup?
    raise FlowError, :characters_missing unless ready?

    transaction do
      fil_rouges = CatalogDrawer.call(kind: :fil_rouge, count: duos.size, random: random)
      actions = CatalogDrawer.call(kind: :special_action, count: duos.size, random: random)
      duos.each_with_index do |duo, index|
        duo.update!(fil_rouge_item: fil_rouges[index], special_action_item: actions[index])
      end
      in_progress!
      setup_next_race!(random: random)
    end
  end

  # Complication (hors celles déjà jouées dans la coupe), cibles et tâche secrète de chaque duo.
  def setup_next_race!(random: Random.new)
    index = races.count
    raise FlowError, :all_races_created if index >= RACES_COUNT

    complication = CatalogDrawer.call(kind: :complication, count: 1, exclude: races.map(&:complication_item), random: random).first
    targets = complication.params["type"] == "targeted" ? duos.map(&:id).sample(complication.params["targets"], random: random) : []
    secret_tasks = CatalogDrawer.call(kind: :secret_task, count: duos.size, random: random)

    transaction do
      race = races.create!(position: index + 1, complication_item: complication, target_duo_ids: targets)
      duos.each_with_index do |duo, duo_index|
        race.checks.create!(duo: duo, kind: "fil_rouge", catalog_item: duo.fil_rouge_item)
        race.checks.create!(duo: duo, kind: "special_action", catalog_item: duo.special_action_item)
        race.checks.create!(duo: duo, kind: "secret_task", catalog_item: secret_tasks[duo_index])
      end
      race
    end
  end

  # Appelé quand une course est terminée : course suivante, ou fin de coupe puis coupe suivante / fin de partie.
  def advance!(random: Random.new)
    if races.reload.size < RACES_COUNT
      setup_next_race!(random: random)
    else
      finished!
      game.cup_finished!(random: random)
    end
  end

  def current_race
    races.reorder(position: :desc).first
  end

  def duo_for(player)
    duos.find { |duo| duo.pilot_id == player.id || duo.judge_id == player.id }
  end

  def game_master_is_judge?
    duos.any? { |duo| duo.judge_id == game_master_id }
  end

  # Rôles du joueur dans la coupe : [:game_master, :judge] pour un MJ juge, [] s'il n'a plus de siège.
  def roles_of(player)
    return [] unless player

    roles = []
    roles << :game_master if player.id == game_master_id
    roles << :pilot if duos.any? { |duo| duo.pilot_id == player.id }
    roles << :judge if duos.any? { |duo| duo.judge_id == player.id }
    roles
  end

  # Chaque siège a exactement un rôle, et le MJ n'est jamais pilote.
  def roles_valid?
    duo_players = duos.flat_map { |duo| [ duo.pilot_id, duo.judge_id ] }
    participants = game_master_is_judge? ? duo_players : duo_players + [ game_master_id ]

    participants.uniq.size == participants.size && participants.size == game.seats.size &&
      duos.none? { |duo| duo.pilot_id == game_master_id }
  end
end
