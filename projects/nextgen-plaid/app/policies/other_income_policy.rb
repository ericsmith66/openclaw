class OtherIncomePolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    owner?
  end

  def create?
    owner?
  end

  def new?
    create?
  end

  def update?
    owner?
  end

  def edit?
    update?
  end

  def destroy?
    owner?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user
      scope.where(user_id: user.id)
    end
  end

  private

  def owner?
    user.present? && record.respond_to?(:user_id) && record.user_id == user.id
  end
end
