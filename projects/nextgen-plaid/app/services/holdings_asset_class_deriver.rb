class HoldingsAssetClassDeriver
  def self.derive!(holding, fmp_sector: nil)
    new(holding, fmp_sector: fmp_sector).derive!
  end

  def initialize(holding, fmp_sector: nil)
    @holding = holding
    @fmp_sector = fmp_sector
  end

  def derive!
    asset_class = derive
    @holding.update!(
      asset_class: asset_class,
      asset_class_source: "derived_plaid",
      asset_class_derived_at: Time.current
    )
  end

  private

  def derive
    type = @holding.type.to_s.strip.downcase
    subtype = @holding.subtype.to_s.strip.downcase
    name = @holding.name.to_s

    # Normalize Plaid security types/subtypes to match holdings grid filter tabs.
    return "etf" if type == "etf"
    return "mutual_fund" if type == "mutual fund" || type == "mutual_fund"
    return "cd" if type == "cd" || subtype.include?("cd")
    return "money_market" if type == "money market" || type == "money_market" || subtype.include?("money market")

    return "cash_equivalent" if @holding.is_cash_equivalent? || type == "cash"

    return "equity" if type == "equity" || subtype.match?(/common|preferred stock/i)
    return "real_estate" if (@fmp_sector || "").to_s == "Real Estate" || name.match?(/\bREIT\b/i)
    return "fixed_income" if type == "fixed income" || type == "fixed_income" || name.match?(/bond|treasury|note/i)

    "other"
  end
end
