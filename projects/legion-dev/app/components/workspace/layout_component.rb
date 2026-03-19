# frozen_string_literal: true

class Workspace::LayoutComponent < ViewComponent::Base
  include Turbo::FramesHelper

  renders_one :left_panel_content
  renders_one :right_panel_content
  renders_one :left_drawer_content
  renders_one :right_drawer_content
  renders_one :toolbar_content
  renders_one :chat_header_content
  renders_one :chat_empty_state

  # @param task [Object, nil] the current task/conversation (nil = empty state)
  # @param workspace_id [String] unique ID for this workspace instance (supports multiple per page)
  # @param left_panel [Hash, false] config for left panel: { width: "280px", collapsible: true, title: "..." }
  # @param right_panel [Hash, false] config for right panel: { width: "480px", collapsible: true, title: "..." }
  # @param left_drawer [Hash, false] config for left drawer: { title: "..." }
  # @param right_drawer [Hash, false] config for right drawer: { title: "..." }
  # @param toolbar [Boolean] whether to show the bottom toolbar
  # @param chat [Hash] chat config: { show_header: true, show_slash_commands: true, placeholder: "..." }
  def initialize(
    task: nil,
    workspace_id: "default",
    left_panel: false,
    right_panel: false,
    left_drawer: false,
    right_drawer: false,
    toolbar: false,
    chat: {}
  )
    @task = task
    @workspace_id = workspace_id
    @left_panel_config = left_panel
    @right_panel_config = right_panel
    @left_drawer_config = left_drawer
    @right_drawer_config = right_drawer
    @toolbar = toolbar
    @chat_config = default_chat_config.merge(chat)
  end

  def left_panel?
    @left_panel_config.is_a?(Hash)
  end

  def right_panel?
    @right_panel_config.is_a?(Hash)
  end

  def left_drawer?
    @left_drawer_config.is_a?(Hash)
  end

  def right_drawer?
    @right_drawer_config.is_a?(Hash)
  end

  def toolbar?
    @toolbar
  end

  def left_panel_width
    @left_panel_config.is_a?(Hash) ? @left_panel_config.fetch(:width, "280px") : "280px"
  end

  def right_panel_width
    @right_panel_config.is_a?(Hash) ? @right_panel_config.fetch(:width, "480px") : "480px"
  end

  def left_panel_collapsible?
    @left_panel_config.is_a?(Hash) && @left_panel_config.fetch(:collapsible, true)
  end

  def right_panel_collapsible?
    @right_panel_config.is_a?(Hash) && @right_panel_config.fetch(:collapsible, true)
  end

  def left_panel_title
    @left_panel_config.is_a?(Hash) ? @left_panel_config.fetch(:title, "") : ""
  end

  def right_panel_title
    @right_panel_config.is_a?(Hash) ? @right_panel_config.fetch(:title, "") : ""
  end

  def left_drawer_title
    @left_drawer_config.is_a?(Hash) ? @left_drawer_config.fetch(:title, "") : ""
  end

  def right_drawer_title
    @right_drawer_config.is_a?(Hash) ? @right_drawer_config.fetch(:title, "") : ""
  end

  def chat_placeholder
    @chat_config.fetch(:placeholder, "Type a message or /command...")
  end

  def show_chat_header?
    @chat_config.fetch(:show_header, true)
  end

  def show_slash_commands?
    @chat_config.fetch(:show_slash_commands, true)
  end

  def dom_id(suffix)
    "workspace-#{@workspace_id}-#{suffix}"
  end

  private

  def default_chat_config
    {
      show_header: true,
      show_slash_commands: true,
      placeholder: "Type a message or /command..."
    }
  end
end
