class UsersController < ApplicationController
  before_action :set_user
  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to dashboard_users_path
      if @user.admin && params[:user][:admin]
        flash.alert = 'Utilizatorul este administrator din acest moment!'
      elsif !@user.admin && params[:user][:admin]
        flash.alert = 'Utilizatorul nu mai are drepturi de administrare!'
      elsif params[:user][:alias]
        flash.alert = params[:user][:alias].empty? ? "Ai uitat să-i pui un alias!" : "Utilizatorul are aliasul #{params[:user][:alias]}!"
      end
    end
  end

  def destroy
    if @user.destroy
      respond_to do |format|
        format.html { redirect_to admin_specialties_path, notice: "User șters!" }
      end
      else
        redirect_to admin_specialties_path, notice: "Se pare că acest user are extra-vieți! Mai încearcă încă o dată ștergerea!"
    end
  end

  private

  def set_user
    @user = authorize User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email, :password, :admin, :alias, :god_mode)
  end
end
