ENV["RAILS_ENV"] ||= "test"

# SimpleCov doit démarrer avant le chargement de l'application.
require "simplecov"

# Dans Docker, le dossier de couverture vit hors du volume monté (renommages concurrents refusés sous Windows).
coverage_path = ENV.fetch("COVERAGE_DIR", File.expand_path("../coverage", __dir__))
FileUtils.rm_f(File.join(coverage_path, ".resultset.json"))

SimpleCov.merge_subprocesses true
SimpleCov.at_fork do |pid|
  SimpleCov.command_name "#{SimpleCov.command_name} (subprocess: #{pid})"
  SimpleCov.print_error_status = false
  SimpleCov.formatter SimpleCov::Formatter::SimpleFormatter
  SimpleCov.start
end

SimpleCov.start "rails" do
  coverage_dir coverage_path
  skip "app/models/application_record.rb"
  group "Models", "app/models"
  group "Services", "app/services"

  # Seuil de 90 % sur les règles métier, uniquement quand bin/ci le demande (pas pour les tests système ni un test isolé).
  if ENV["COVERAGE_CHECK"]
    coverage(:line) do
      minimum 90, per: group("Models")
      minimum 90, per: group("Services")
    end
  end
end

require_relative "../config/environment"
require "rails/test_help"

Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |file| require file }

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    parallelize_setup { |worker| SimpleCov.at_fork.call(worker) }

    fixtures :all

    include SeededRandom
    include GameBuilder
    include GamePlayer
    include CatalogHelper
  end
end

class ActionDispatch::IntegrationTest
  include SignInHelper
end
