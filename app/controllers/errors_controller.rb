class ErrorsController < ApplicationController
  before_action :skip_authorization
  def not_found
    redirect_to root_path
    flash.alert = "Pagina căutată nu există. Redirecționare către pagina principală!"
  end

  def internal_server_error
    redirect_to root_path
    flash.alert = "Pagina căutată nu există. Redirecționare către pagina principală!"
  end
end
