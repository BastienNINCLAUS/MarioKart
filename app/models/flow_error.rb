# Erreur de déroulement (mauvais rôle, mauvaise étape) ; reason sert de clé de traduction (flow_errors.*).
class FlowError < StandardError
  attr_reader :reason

  def initialize(reason)
    @reason = reason
    super(reason.to_s)
  end
end
