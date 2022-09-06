class SpecialtyPolicy < ApplicationPolicy
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
    new?
  end
  def all_specialties?
    true
  end
  def show?
    new?
  end
  def about?
    true
  end
  def destroy?
    new?
  end
end
