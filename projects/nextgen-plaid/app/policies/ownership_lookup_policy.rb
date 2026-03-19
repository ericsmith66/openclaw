class OwnershipLookupPolicy < ApplicationPolicy
  def index?
    admin_or_parent?
  end

  def show?
    admin_or_parent?
  end

  def create?
    admin_or_parent?
  end

  def update?
    admin_or_parent?
  end

  def destroy?
    admin_or_parent?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user && (user.admin? || user.parent?)

      scope.all
    end
  end

  private

  def admin_or_parent?
    user && (user.admin? || user.parent?)
  end
end
