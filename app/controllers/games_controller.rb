class GamesController < ApplicationController
  include GameScoped

  before_action :set_game, only: %i[show start]
  before_action :require_player, only: %i[show start]

  def new; end

  def create
    rotate = ActiveModel::Type::Boolean.new.cast(params.fetch(:rotate_game_master, true))
    game = Game.create_with_host!(nickname: params[:nickname].to_s, rotate_game_master: rotate)
    sign_in(game.host)
    redirect_to game_path(game)
  rescue ActiveRecord::RecordInvalid => error
    flash.now[:alert] = error.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_content
  end

  def show; end

  def start
    @game.start!(by: current_player, cups_count: params[:cups_count])
    redirect_to game_path(@game)
  rescue Game::CannotStart => error
    redirect_to game_path(@game), alert: t("games.start_errors.#{error.reason}",
                                           min: CupCountCalculator::DEFAULT, max: CupCountCalculator::MAX)
  end
end
