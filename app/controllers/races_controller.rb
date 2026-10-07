class RacesController < ApplicationController
  include GameScoped

  before_action :set_game
  before_action :require_player
  before_action :set_race

  def start
    @race.start!(by: current_player)
    redirect_to game_path(@game)
  end

  def finish
    positions = @race.cup.duos.to_h { |duo| [ duo.id, params.dig(:positions, duo.id.to_s) ] }
    @race.finish!(by: current_player, positions: positions,
                  rejected_check_ids: Array(params[:rejected]), cancelled_duo_ids: Array(params[:cancelled]))
    redirect_to game_path(@game)
  end

  private

  def set_race
    @race = Race.joins(:cup).where(cups: { game_id: @game.id }).find(params[:id])
  end
end
