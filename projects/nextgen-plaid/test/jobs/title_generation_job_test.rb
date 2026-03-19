require "test_helper"

class TitleGenerationJobTest < ActiveJob::TestCase
  test "updates title from smart proxy response" do
    user = users(:one)
    conversation = PersonaConversation.create!(
      user: user,
      persona_id: "financial-advisor",
      llm_model: "llama3.1:70b",
      title: "Chat Jan 01"
    )
    conversation.persona_messages.create!(role: "user", content: "How do I think about intrinsic value?")

    fake_client = Minitest::Mock.new
    fake_client.expect(:chat, { "choices" => [ { "message" => { "content" => "Intrinsic value basics" } } ] }, [ Array ])

    AgentHub::SmartProxyClient.stub(:new, fake_client) do
      perform_enqueued_jobs do
        TitleGenerationJob.perform_later(conversation.id)
      end
    end

    conversation.reload
    assert_equal "Intrinsic value basics", conversation.title
    fake_client.verify
  end
end
