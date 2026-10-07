class CupsController < ApplicationController
  include GameScoped

  before_action :set_game
  before_action :require_player
  before_action :set_cup
  before_action :require_game_master

  def swap
    RoleAdjuster.swap!(cup: @cup, player: @game.players.find(params[:player_id]), other: @game.players.find(params[:other_id]))
    redirect_to game_path(@game)
  rescue RoleAdjuster::Invalid => error
    redirect_to game_path(@game), alert: t("cups.swap_errors.#{error.reason}")
  end

  def start
    @cup.start!(by: current_player)
    redirect_to game_path(@game)
  end

  private

  def set_cup
    @cup = @game.cups.find(params[:id])
  end

  def require_game_master
    redirect_to game_path(@game), alert: t("cups.errors.not_game_master") unless current_player == @cup.game_master
  end
end
