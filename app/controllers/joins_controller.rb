class JoinsController < ApplicationController
  include PlayerSession

  def create
    @game = Game.find_by(code: params[:code].to_s.strip.upcase)
    return render_form(t(".unknown_code")) unless @game

    nickname = Player.normalize_value_for(:nickname, params[:nickname].to_s)
    existing = @game.players.find_by("lower(nickname) = ?", nickname.downcase)
    return redirect_to game_path(@game) if existing && existing == current_player

    player = enter(nickname)
    return render_form(@errors) unless player

    sign_in(player)
    redirect_to game_path(@game)
  end

  private

  # Lobby : nouveau joueur. Partie en cours : seule la reprise d'un siège libre est possible.
  def enter(nickname)
    if @game.in_progress? && @game.open_seats.exists?
      ReplacementService.fill_seat!(game: @game, nickname: nickname)
    else
      player = @game.players.new(nickname: nickname)
      return player if @game.with_lock { player.save }

      @errors = player.errors.full_messages.to_sentence
      nil
    end
  rescue ActiveRecord::RecordInvalid => error
    @errors = error.record.errors.full_messages.to_sentence
    nil
  end

  def render_form(message)
    flash.now[:alert] = message
    render "games/new", status: :unprocessable_content
  end
end
