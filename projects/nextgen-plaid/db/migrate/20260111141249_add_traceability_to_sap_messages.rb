class AddTraceabilityToSapMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :sap_messages, :rag_request_id, :string
    add_column :sap_messages, :model, :string
  end
end
