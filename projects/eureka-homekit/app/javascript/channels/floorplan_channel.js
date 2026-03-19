import consumer from "./consumer"

export default (callbacks) => {
  return consumer.subscriptions.create("FloorplanChannel", {
    connected() {
      if (callbacks.connected) callbacks.connected()
    },

    disconnected() {
      if (callbacks.disconnected) callbacks.disconnected()
    },

    received(data) {
      if (callbacks.received) callbacks.received(data)
    }
  });
}
