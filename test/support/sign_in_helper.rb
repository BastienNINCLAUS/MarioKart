# Pour les tests d'intégration : pose le cookie signé d'un joueur existant.
module SignInHelper
  def sign_in_as(player)
    name = PlayerSession.cookie_name(player.game)
    jar = ActionDispatch::Request.new(Rails.application.env_config.deep_dup).cookie_jar
    jar.signed[name] = player.session_token
    cookies[name] = jar[name]
  end
end
