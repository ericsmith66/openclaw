# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Accessories#batch_control", type: :request do
  let(:home) { create(:home, name: "Test Home") }
  let(:room) { create(:room, home: home, name: "Living Room") }

  let!(:light) do
    acc = create(:accessory, room: room, name: "Light 1", uuid: "light-uuid-1")
    create(:sensor, accessory: acc, characteristic_type: "On", is_writable: true,
           characteristic_uuid: "on-char-1", service_uuid: "svc-1", service_type: "Lightbulb")
    create(:sensor, accessory: acc, characteristic_type: "Brightness", is_writable: true,
           characteristic_uuid: "bri-char-1", service_uuid: "svc-1", service_type: "Lightbulb")
    acc
  end

  let!(:switch_acc) do
    acc = create(:accessory, room: room, name: "Switch 1", uuid: "switch-uuid-1")
    create(:sensor, accessory: acc, characteristic_type: "On", is_writable: true,
           characteristic_uuid: "on-char-2", service_uuid: "svc-2", service_type: "Switch")
    acc
  end

  let!(:readonly_acc) do
    acc = create(:accessory, room: room, name: "Sensor Only", uuid: "readonly-uuid-1")
    create(:sensor, accessory: acc, characteristic_type: "Current Temperature", is_writable: false,
           characteristic_uuid: "temp-char-1", service_uuid: "svc-3", service_type: "TemperatureSensor")
    acc
  end

  before do
    allow(PrefabControlService).to receive(:set_characteristic).and_return({ success: true, latency_ms: 100 })
  end

  describe "POST /accessories/batch_control" do
    it "returns 400 when accessory_ids is missing" do
      post accessories_batch_control_path, params: { action_type: "turn_on" }, as: :json
      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("accessory_ids")
    end

    it "returns 400 when action_type is missing" do
      post accessories_batch_control_path, params: { accessory_ids: [ "light-uuid-1" ] }, as: :json
      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("action_type")
    end

    it "returns 400 for unknown action_type" do
      post accessories_batch_control_path, params: {
        accessory_ids: [ "light-uuid-1" ],
        action_type: "explode"
      }, as: :json
      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("Unknown action_type")
    end

    context "turn_on action" do
      it "sends On=true to all selected accessories" do
        post accessories_batch_control_path, params: {
          accessory_ids: [ "light-uuid-1", "switch-uuid-1" ],
          action_type: "turn_on"
        }, as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["total"]).to eq(2)
        expect(json["succeeded"]).to eq(2)
        expect(json["failed"]).to eq(0)
        expect(json["results"].size).to eq(2)

        expect(PrefabControlService).to have_received(:set_characteristic).twice
      end
    end

    context "turn_off action" do
      it "sends On=false to all selected accessories" do
        post accessories_batch_control_path, params: {
          accessory_ids: [ "light-uuid-1" ],
          action_type: "turn_off"
        }, as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["succeeded"]).to eq(1)

        expect(PrefabControlService).to have_received(:set_characteristic).with(
          hash_including(characteristic: "On", value: false)
        )
      end
    end

    context "set_brightness action" do
      it "sends Brightness value to accessories with Brightness sensor" do
        post accessories_batch_control_path, params: {
          accessory_ids: [ "light-uuid-1" ],
          action_type: "set_brightness",
          value: "75"
        }, as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["succeeded"]).to eq(1)

        expect(PrefabControlService).to have_received(:set_characteristic).with(
          hash_including(characteristic: "Brightness", value: 75)
        )
      end

      it "reports failure for accessories without Brightness sensor" do
        post accessories_batch_control_path, params: {
          accessory_ids: [ "switch-uuid-1" ],
          action_type: "set_brightness",
          value: "50"
        }, as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["failed"]).to eq(1)
        expect(json["results"].first["error"]).to include("not writable")
      end
    end

    context "partial failure" do
      it "does not stop batch when individual accessories fail" do
        allow(PrefabControlService).to receive(:set_characteristic).and_return(
          { success: false, error: "Device offline", latency_ms: 200 },
          { success: true, latency_ms: 100 }
        )

        post accessories_batch_control_path, params: {
          accessory_ids: [ "light-uuid-1", "switch-uuid-1" ],
          action_type: "turn_on"
        }, as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["succeeded"]).to eq(1)
        expect(json["failed"]).to eq(1)
        expect(json["results"].size).to eq(2)
      end
    end

    context "with unknown accessory UUIDs" do
      it "silently skips accessories that don't exist" do
        post accessories_batch_control_path, params: {
          accessory_ids: [ "nonexistent-uuid" ],
          action_type: "turn_on"
        }, as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["total"]).to eq(0)
      end
    end

    it "uses 'web-batch' as the source for audit logging" do
      post accessories_batch_control_path, params: {
        accessory_ids: [ "light-uuid-1" ],
        action_type: "turn_on"
      }, as: :json

      expect(PrefabControlService).to have_received(:set_characteristic).with(
        hash_including(source: "web-batch")
      )
    end
  end
end
