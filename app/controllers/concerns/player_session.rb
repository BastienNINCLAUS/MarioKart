# Identité d'un joueur : un cookie signé par partie contenant son session_token.
module PlayerSession
  extend ActiveSupport::Concern

  def self.cookie_name(game)
    "player_#{game.code}"
  end

  included do
    helper_method :current_player
  end

  private

  def sign_in(player)
    cookies.signed.permanent[PlayerSession.cookie_name(player.game)] = {
      value: player.session_token, httponly: true, same_site: :lax
    }
  end

  def current_player
    return @current_player if defined?(@current_player)

    token = @game && cookies.signed[PlayerSession.cookie_name(@game)]
    @current_player = token.present? ? @game.players.find_by(session_token: token) : nil
  end
end
