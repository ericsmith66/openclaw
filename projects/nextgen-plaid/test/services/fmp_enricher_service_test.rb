require "test_helper"

class FmpEnricherServiceTest < ActiveSupport::TestCase
  class FakeClient
    def initialize(responses_by_path)
      @responses_by_path = responses_by_path
    end

    def get_json(url, query:, retries:) # rubocop:disable Lint/UnusedMethodArgument
      path = URI(url).path
      @responses_by_path.fetch(path)
    end
  end

  test "extracts beta from profile, debt_to_equity from ratios.debtToEquityRatio, and pe_ratio from ratios.priceToEarningsRatio" do
    client = FakeClient.new(
      "/stable/profile" => [ { "companyName" => "Example Co", "beta" => 1.23 } ],
      "/stable/quote" => [ { "price" => 10.0 } ],
      "/stable/key-metrics" => [ {} ],
      "/stable/ratios" => [ { "debtToEquityRatio" => 0.56, "priceToEarningsRatio" => 12.34 } ]
    )

    service = FmpEnricherService.new(api_key: "test", client: client)
    data = service.enrich("AAPL")

    assert_equal 1.23, data["beta"]
    assert_equal 0.56, data["debt_to_equity"]
    assert_equal 12.34, data["pe_ratio"]
  end
end
