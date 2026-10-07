class DisputesController < ApplicationController
  include GameScoped

  before_action :set_game
  before_action :require_player
  before_action :set_dispute

  def decide
    @dispute.decide!(by: current_player, approve: approve?)
    redirect_to game_path(@game)
  end

  def start_vote
    @dispute.start_vote!(by: current_player)
    redirect_to game_path(@game)
  end

  def close_vote
    @dispute.close_vote!(by: current_player)
    redirect_to game_path(@game)
  end

  def vote
    @dispute.vote!(by: current_player, approve: approve?)
    redirect_to game_path(@game)
  end

  private

  def set_dispute
    @dispute = Dispute.joins(check: { race: :cup }).where(cups: { game_id: @game.id }).find(params[:id])
  end

  def approve?
    ActiveModel::Type::Boolean.new.cast(params[:approve])
  end
end
