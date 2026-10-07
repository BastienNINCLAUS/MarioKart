class ChecksController < ApplicationController
  include GameScoped

  before_action :set_game
  before_action :require_player

  def update
    check = Check.joins(race: :cup).where(cups: { game_id: @game.id }).find(params[:id])
    check.tick!(by: current_player, achieved: ActiveModel::Type::Boolean.new.cast(params[:achieved]))
    redirect_to game_path(@game)
  end

  def contest
    check = Check.joins(race: :cup).where(cups: { game_id: @game.id }).find(params[:id])
    check.contest!(by: current_player)
    redirect_to game_path(@game)
  end
end
