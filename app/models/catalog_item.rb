class CatalogItem < ApplicationRecord
  VISIBILITIES_BY_KIND = {
    "fil_rouge" => %w[secret_duo],
    "secret_task" => %w[secret_duo],
    "special_action" => %w[secret_until_done],
    "complication" => %w[public secret]
  }.freeze
  COMPLICATION_TYPES = %w[targeted global constraint].freeze
  COMPLICATION_CALCULATIONS = %w[auto manual].freeze

  enum :kind, {
    fil_rouge: "fil_rouge",
    complication: "complication",
    secret_task: "secret_task",
    special_action: "special_action"
  }, validate: true

  validates :key, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/, allow_blank: true }
  validates :name, :description, presence: true
  validates :points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :visibility, inclusion: { in: ->(item) { VISIBILITIES_BY_KIND.fetch(item.kind, []) } }
  validate :complication_params_are_valid

  private

  def complication_params_are_valid
    return unless complication?

    errors.add(:params, :invalid) unless COMPLICATION_TYPES.include?(params["type"]) &&
                                         COMPLICATION_CALCULATIONS.include?(params["calculation"])
    return unless params["type"] == "targeted"

    errors.add(:params, :invalid) unless params["targets"].is_a?(Integer) && params["targets"].positive?
  end
end
