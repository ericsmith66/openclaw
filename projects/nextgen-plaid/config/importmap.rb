# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "controllers/artifact_preview_controller", to: "controllers/artifact_preview_controller.js"

# Explicit pin for persona chat streaming controller.
# Some deployments were observed to omit dashed controller filenames from the rendered importmap.
pin "controllers/streaming_chat_controller", to: "controllers/streaming_chat_controller.js"
pin "@rails/actioncable", to: "https://cdn.jsdelivr.net/npm/@rails/actioncable@7.2.200/+esm"
pin "marked" # @17.0.1
pin "chartkick" # @5.0.1

# Chart.js
# IMPORTANT: Chart.js is now loaded via script tag in application.html.erb
# to avoid ESM/UMD import compatibility issues with importmap.
# The script tag sets window.Chart which Chartkick then uses.
# Previously caused: "Importing binding name 'default' cannot be resolved by star export entries"
# pin "chart.js", to: "https://cdn.jsdelivr.net/npm/chart.js@4.5.1/dist/chart.umd.js" # DISABLED
# Shim for chart.js so modules can import it
pin "chart.js", to: "shims/chart.js"
