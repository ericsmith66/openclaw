Rails.application.routes.draw do
  # Turbo Streams use ActionCable websockets.
  # Without this mount, the browser will never open a `/cable` websocket connection.
  # Public static pages for Twilio A2P compliance
  get "/privacy", to: "static#privacy"
  get "/terms", to: "static#terms"

  # Public health check endpoint — token protected via HEALTH_TOKEN env var
  get "/health", to: "health#show"

  mount ActionCable.server => "/cable"

  post "/plaid_items/:id/refresh", to: "plaid_refreshes#create", as: :plaid_item_refresh
  post "/plaid_items/:id/retry", to: "plaid_item_retries#create", as: :plaid_item_retry
  namespace :agents do
    get "monitor", to: "monitor#index"
  end
  get "plaid_oauth/initiate"
  get "plaid_oauth/callback"
  devise_for :users

  # Authenticated users get dashboard FIRST
  authenticated :user do
    root "net_worth/dashboard#show", as: :authenticated_root
  end

  # Public users get welcome SECOND
  root "welcome#index"

  # Legacy dashboard route (compat alias)
  # NOTE: kept as a 200 (no redirect) to satisfy existing integration tests and
  # to avoid breaking bookmarks; it serves the same content as `/net_worth/dashboard`.
  get "/dashboard", to: "net_worth/dashboard#show"

  namespace :net_worth do
    get "dashboard", to: "dashboard#show"
    post "sync", to: "syncs#create"
    get "allocations", to: "allocations#show"
    get "sectors", to: "sectors#show"
    get "performance", to: "performance#show"
    get "holdings", to: "holdings#show"
    get "transactions", to: redirect("/transactions/summary")
    get "income", to: "income#show"
  end

  # Epic 5 (NextGen) main holdings grid
  get "/portfolio/holdings", to: "portfolio/holdings#index", as: :portfolio_holdings

  # Epic 5 (NextGen) snapshot selector support UI (PRD 5-11) / management page (PRD 5-13)
  get "/portfolio/holdings/snapshots", to: "portfolio/holdings_snapshots#index", as: :portfolio_holdings_snapshots

  # Epic 5 (NextGen) security detail page
  get "/portfolio/securities/:security_id", to: "portfolio/securities#show", as: :portfolio_security

  get "/transactions/regular", to: "transactions#regular"
  get "/transactions/investment", to: "transactions#investment"
  get "/transactions/credit", to: "transactions#credit"
  get "/transactions/transfers", to: "transactions#transfers"
  get "/transactions/summary", to: "transactions#summary"

  get "/accounts/link", to: "accounts#link"
  get "/settings/brokerage_connect", to: "settings#brokerage_connect"
  get "/simulations", to: "simulations#index"

  resources :saved_account_filters, except: [ :show ]

  resources :other_incomes, except: [ :show ]

  post "/plaid/link_token", to: "plaid#link_token"
  post "/plaid/exchange",   to: "plaid#exchange"
  get  "/plaid/sync_logs",  to: "plaid#sync_logs"
  post "/plaid/webhook",    to: "plaid_webhook#create"

  # Agent Hub (owner-only)
  get "/agent_hub", to: "agent_hubs#show"
  get "/agent_hub/messages/:agent_id", to: "agent_hubs#messages", as: :agent_hub_messages
  post "/agent_hub/uploads", to: "agent_hub/uploads#create", as: :agent_hub_uploads
  resources :agent_hubs, only: [] do
    collection do
      post :update_model
      get :inspect_context
      delete :archive_run
      post :create_conversation
      post :switch_conversation
      delete :archive_conversation
    end
  end

  # Persona Chats (user-facing)
  get "/chats", to: redirect("/chats/financial-advisor")
  get "/chats/:persona_id", to: "persona_chats#index", as: :persona_chats
  get "/chats/:persona_id/conversations", to: "persona_chats#conversations", as: :persona_chat_conversations
  post "/chats/:persona_id/conversations", to: "persona_chats#create_conversation", as: :persona_chat_create_conversation
  get "/chats/:persona_id/conversations/:id", to: "persona_chats#show", as: :persona_chat_conversation
  patch "/chats/:persona_id/conversations/:id/model", to: "persona_chats#update_model", as: :persona_chat_update_model
  get "/chats/:persona_id/messages/:id/render", to: "persona_chats#render_message", as: :persona_chat_render_message

  # Mission Control (owner-only)
  get "/mission_control", to: "mission_control#index"
  post "/mission_control/nuke", to: "mission_control#nuke"
  post "/mission_control/sync_holdings_now", to: "mission_control#sync_holdings_now"
  post "/mission_control/enrich_holdings_now", to: "mission_control#enrich_holdings_now"
  post "/mission_control/sync_transactions_now", to: "mission_control#sync_transactions_now"
  post "/mission_control/sync_liabilities_now", to: "mission_control#sync_liabilities_now"
  post "/mission_control/refresh_everything_now", to: "mission_control#refresh_everything_now"
  post "/mission_control/relink/:id", to: "mission_control#relink", as: :mission_control_relink
  post "/mission_control/relink_success/:id", to: "mission_control#relink_success", as: :mission_control_relink_success
  post "/mission_control/remove_item/:id", to: "mission_control#remove_item", as: :mission_control_remove_item
  post "/mission_control/fire_webhook/:id", to: "mission_control#fire_webhook", as: :mission_control_fire_webhook
  post "/mission_control/update_webhook_url/:id", to: "mission_control#update_webhook_url", as: :mission_control_update_webhook_url
  get  "/mission_control/plaid_items/:id/edit", to: "mission_control#edit_plaid_item", as: :edit_mission_control_plaid_item
  patch "/mission_control/plaid_items/:id", to: "mission_control#update_plaid_item", as: :mission_control_plaid_item
  get  "/mission_control/logs", to: "mission_control#logs", defaults: { format: :json }
  get  "/mission_control/costs", to: "mission_control#costs"
  get  "/mission_control/costs/export.csv", to: "mission_control#export_costs", as: :export_mission_control_costs

  # Model inspection views
  resources :holdings
  resources :transactions
  resources :accounts

  # PRD UI-4: Admin namespace for user/account CRUD
  namespace :admin do
    resources :users
    resources :accounts
    resources :ownership_lookups
    resources :snapshots, only: [ :index, :show ]
    get "ai_workflow", to: "ai_workflow#index"
    get "health", to: "health#index"
    get "rag_inspector", to: "rag_inspector#index"
    get "sap_collaborate", to: "sap_collaborate#index"
    post "sap_collaborate/ask", to: "sap_collaborate#ask"
  end

  namespace :api do
    resources :snapshots, only: [] do
      member do
        get :download
        get :rag_context
      end
    end
  end
end

#
