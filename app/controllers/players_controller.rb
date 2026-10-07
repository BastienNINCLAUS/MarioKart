class PlayersController < ApplicationController
  include GameScoped

  before_action :set_game
  before_action :require_player
  before_action :set_player

  def abandon
    ReplacementService.abandon!(game: @game, by: current_player, player: @player)
    redirect_to game_path(@game)
  end

  def reinstate
    ReplacementService.reinstate!(game: @game, by: current_player, player: @player)
    redirect_to game_path(@game)
  end

  private

  def set_player
    @player = @game.players.find(params[:id])
  end
end
