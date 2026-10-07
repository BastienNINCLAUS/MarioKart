require "application_system_test_case"

class HealthCheckSystemTest < ApplicationSystemTestCase
  test "le navigateur headless atteint l'application" do
    visit rails_health_check_path

    assert_selector "body"
  end
end
