require "test_helper"

class HealthCheckTest < ActionDispatch::IntegrationTest
  test "l'application démarre et répond sur /up" do
    get rails_health_check_path

    assert_response :success
  end
end
