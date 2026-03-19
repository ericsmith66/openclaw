import { Application } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

const application = Application.start()

// Create consumer with robust logging
const consumer = createConsumer()

// Track connection health
consumer.connection.onOpen = () => console.log("[ActionCable] Connection established")
consumer.connection.onClose = () => console.warn("[ActionCable] Connection closed")
consumer.connection.onError = (error) => console.error("[ActionCable] Connection error:", error)

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application

// TemperatureConverter for JavaScript (mirrors Ruby helper)
window.TemperatureConverter = {
  toFahrenheit: function(celsius) {
    return Math.round((celsius * 9.0 / 5.0 + 32.0) * 10) / 10
  },
  toCelsius: function(fahrenheit) {
    return Math.round((fahrenheit - 32.0) * 5.0 / 9.0 * 10) / 10
  }
}

export { application, consumer }
