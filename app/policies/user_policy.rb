class UserPolicy < ApplicationPolicy
  # Admins create accounts from /dashboard/users (a signed-in admin cannot use
  # Devise's sign-up, which only serves signed-out visitors).
  def create?
    user.admin
  end

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
