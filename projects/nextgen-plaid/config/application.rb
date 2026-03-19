require_relative "boot"

require "rails/all"
require "attr_encrypted"
# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module NextgenPlaid
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Propshaft / Importmap:
    # Ensure `app/javascript` is on the assets load path early in boot so
    # importmap pins under `controllers/*` can be resolved.
    # (Configuring this only in `config/initializers/assets.rb` is too late for Propshaft.)
    config.assets.paths << Rails.root.join("app", "javascript")

    config.middleware.use Rack::Attack
  end
end
