# Retrouve la partie et le joueur courant ; la partie est identifiée par :game_code (routes imbriquées) ou :code.
module GameScoped
  extend ActiveSupport::Concern

  included do
    include PlayerSession

    rescue_from FlowError do |error|
      redirect_to game_path(@game), alert: t("flow_errors.#{error.reason}")
    end
  end

  private

  def set_game
    @game = Game.find_by!(code: (params[:game_code] || params[:code]).to_s.upcase)
  end

  def require_player
    redirect_to root_path(code: @game.code), alert: t("games.errors.not_member") unless current_player
  end
end
