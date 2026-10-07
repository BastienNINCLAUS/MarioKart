class DuosController < ApplicationController
  include GameScoped

  before_action :set_game
  before_action :require_player
  before_action :set_duo
  before_action :require_judge

  def update
    if @duo.cup.setup? && @duo.update(character: params[:character].presence)
      redirect_to game_path(@game)
    else
      message = @duo.errors.full_messages.to_sentence.presence || t("duos.errors.cup_started")
      redirect_to game_path(@game), alert: message
    end
  end

  private

  def set_duo
    @duo = Duo.joins(:cup).where(cups: { game_id: @game.id }).find(params[:id])
  end

  def require_judge
    redirect_to game_path(@game), alert: t("duos.errors.not_judge") unless current_player == @duo.judge
  end
end
