module ApplicationHelper
  def markdown(text)
    Ai::MarkdownRenderer.render(text)
  end
end
