  class ReviewPolicy < ApplicationPolicy
    class Scope < Scope
      def resolve
        scope.all
      end
    end

    def new?
      true
    end

    def create?
      new?
    end

    def destroy?
      user.admin || user.super_admin
    end

    def edit?
      destroy?
    end

    def update?
      destroy?
    end
  end
