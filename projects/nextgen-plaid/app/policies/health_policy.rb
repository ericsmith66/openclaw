class HealthPolicy < ApplicationPolicy
  def index?
    user&.admin?
  end
end
