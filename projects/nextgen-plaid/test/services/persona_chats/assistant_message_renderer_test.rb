require "test_helper"

class PersonaChats::AssistantMessageRendererTest < ActiveSupport::TestCase
  test "renders markdown to HTML and includes model meta" do
    html = PersonaChats::AssistantMessageRenderer.call(
      content: "# Title\n\n- one\n- two\n",
      sources: [],
      model: "grok-4",
      provider_model: "grok-4"
    )

    assert_includes html, "<div class=\"prose max-w-none\">"
    # Renderer may include an anchor link inside headings.
    assert_includes html, "<h1>"
    assert_includes html, "Title</h1>"
    assert_includes html, "<li>one</li>"
    assert_includes html, "Model:"
    assert_includes html, "<code>grok-4</code>"
  end

  test "renders sources list when provided" do
    html = PersonaChats::AssistantMessageRenderer.call(
      content: "Hello",
      sources: %w[https://example.com/a https://example.com/a https://example.com/b],
      model: "",
      provider_model: ""
    )

    assert_includes html, "Sources"
    assert_includes html, "https://example.com/a"
    assert_includes html, "https://example.com/b"
  end
end
