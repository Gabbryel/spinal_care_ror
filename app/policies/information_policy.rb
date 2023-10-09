class InformationPolicy < ApplicationPolicy
  def new?
    user.admin
  end
  def create?
    new?
  end
  def edit?
    new?
  end
  def update?
    new?
  end
  def index?
    true
  end
  def show?
    true
  end
  def destroy?
    new?
  end
end
