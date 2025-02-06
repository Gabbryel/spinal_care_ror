class MedicalServicePolicy < ApplicationPolicy
  def new?
    user && user.admin
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
    new?
  end
  def show_by_specialty?
    true
  end
  def destroy?
    new?
  end
end
