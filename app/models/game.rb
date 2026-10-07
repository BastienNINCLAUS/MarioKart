class Game < ApplicationRecord
  CODE_ALPHABET = %w[A B C D E F G H J K L M N P Q R S T U V W X Y Z 2 3 4 5 6 7 8 9].freeze
  CODE_LENGTH = 5
  MIN_PLAYERS = 4
  MAX_PLAYERS = 9

  class CannotStart < StandardError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super(reason.to_s)
    end
  end

  class CannotSetupCup < StandardError; end

  belongs_to :host, class_name: "Player", optional: true
  has_many :cups, -> { order(:position) }, dependent: :destroy
  has_many :players, dependent: :destroy

  enum :status, { lobby: "lobby", in_progress: "in_progress", finished: "finished" }, default: :lobby

  before_validation :assign_code, on: :create
  validates :code, presence: true, uniqueness: true

  after_update_commit :broadcast_refresh, if: :saved_change_to_status?

  def self.create_with_host!(nickname:, rotate_game_master: true)
    transaction do
      game = create!(rotate_game_master: rotate_game_master)
      game.update!(host: game.players.create!(nickname: nickname))
      game
    end
  end

  def self.generate_code
    Array.new(CODE_LENGTH) { CODE_ALPHABET.sample(random: SecureRandom) }.join
  end

  def to_param
    code
  end

  def start!(by:, cups_count: nil, random: Random.new)
    raise CannotStart, :not_host unless by.present? && by == host
    raise CannotStart, :not_lobby unless lobby?
    raise CannotStart, :wrong_player_count unless players.count.between?(MIN_PLAYERS, MAX_PLAYERS)

    calculator = CupCountCalculator.new(players.count)
    cups_count = cups_count.presence ? Integer(cups_count, exception: false) : calculator.default
    raise CannotStart, :invalid_cups_count unless calculator.valid?(cups_count)

    transaction do
      update!(status: :in_progress, cups_count: cups_count)
      setup_next_cup!(random: random)
    end
  end

  # Sièges dans l'ordre de rotation du MJ (hôte d'abord, puis ordre d'arrivée). Chaque siège est la
  # chaîne [joueur d'origine, remplaçant, remplaçant du remplaçant…] ; le dernier maillon le tient.
  def seats
    everyone = players.order(:id).to_a
    successors = everyone.select(&:replaces_id).index_by(&:replaces_id)
    originals = everyone.reject(&:replaces_id)
    originals = [ host, *(originals - [ host ]) ]

    originals.map do |original|
      chain = [ original ]
      chain << successors.fetch(chain.last.id) while successors.key?(chain.last.id)
      chain
    end
  end

  def rotation_order
    seats.map(&:last)
  end

  # Joueurs ayant abandonné dont personne n'a encore pris la place.
  def open_seats
    players.abandoned.where.missing(:replacement).order(:id)
  end

  def current_cup
    cups.reorder(position: :desc).first
  end

  def checks
    Check.joins(race: :cup).where(cups: { game_id: id })
  end

  def disputes
    Dispute.joins(check: { race: :cup }).where(cups: { game_id: id })
  end

  # Coupe suivante tirée automatiquement ; la partie se termine après la dernière.
  def cup_finished!(random: Random.new)
    if cups.reload.size < cups_count
      setup_next_cup!(random: random)
    else
      finished!
    end
  end

  def ranking
    entries = ScoreEntry.where(game_id: id)
    cup_points = entries.group(:cup_id, :player_id).sum(:points).each_with_object({}) do |((cup_id, player_id), points), result|
      (result[cup_id] ||= {})[player_id] = points
    end

    Ranking.call(
      players: players.order(:id).to_a.map(&:id),
      points: entries.group(:player_id).sum(:points),
      special_actions: entries.where(kind: "special_action").group(:player_id).count,
      secret_tasks: entries.where(kind: "secret_task").group(:player_id).count,
      cup_points: cup_points
    )
  end

  def setup_next_cup!(random: Random.new)
    raise CannotSetupCup, "la partie n'est pas en cours" unless in_progress?
    raise CannotSetupCup, "toutes les coupes sont créées" if cups.count >= cups_count
    raise CannotSetupCup, "la coupe précédente n'est pas terminée" unless cups.reload.all?(&:finished?)

    seats = self.seats
    ring = seats.map(&:last)
    index = cups.count
    pilot_counts = Duo.joins(:cup).where(cups: { game_id: id }).group(:pilot_id).count
    plan = RoleDistributor.call(
      ring: ring, rotate: rotate_game_master, cups_count: cups_count, cup_index: index,
      pilot_counts: seats.to_h { |chain| [ chain.last, chain.sum { |player| pilot_counts.fetch(player.id, 0) } ] }, random: random
    )

    transaction do
      cup = cups.create!(position: index + 1, game_master: plan.game_master)
      plan.pairs.each { |pilot, judge| cup.duos.create!(pilot: pilot, judge: judge) }
      cup
    end
  end

  private

  def assign_code
    return if code.present?

    self.code = loop do
      candidate = self.class.generate_code
      break candidate unless self.class.exists?(code: candidate)
    end
  end
end
