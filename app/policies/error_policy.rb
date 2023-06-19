class ErrorPolicy < ApplicationPolicy
  def not_found?
    true
  end

  def internal_server_error?
    true
  end
end
