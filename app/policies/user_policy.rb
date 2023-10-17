class UserPolicy < ApplicationPolicy
  def edit?
    user.admin
  end

  def update?
    edit?
  end

  def destroy?
    edit?
  end
end
