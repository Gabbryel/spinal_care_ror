class UsersController < ApplicationController
  before_action :set_user, except: :create

  def edit
  end

  # New account from the dashboard: email, a first password the admin passes
  # on, and optionally the SEO specialist role. Admin rights are still granted
  # afterwards with the God Mode buttons.
  def create
    user = authorize User.new(new_user_params)
    if user.save
      role = user.seo_specialist? ? ' (SEO specialist: vede doar secțiunea de analytics)' : ''
      redirect_to dashboard_users_path, alert: "Contul #{user.email} a fost creat#{role}."
    else
      redirect_to dashboard_users_path, alert: "Contul nu a fost creat: #{user.errors.full_messages.to_sentence}."
    end
  end

  def update
    if @user.update(user_params)
      redirect_to dashboard_users_path
      if @user.admin && params[:user][:admin]
        flash.alert = 'Utilizatorul este administrator din acest moment!'
      elsif !@user.admin && params[:user][:admin]
        flash.alert = 'Utilizatorul nu mai are drepturi de administrare!'
      elsif params[:user].key?(:seo_specialist)
        flash.alert = @user.seo_specialist? ? 'Utilizatorul este SEO specialist: vede doar secțiunea de analytics.' : 'Utilizatorul nu mai este SEO specialist.'
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

  def new_user_params
    params.require(:user).permit(:email, :password, :alias, :seo_specialist)
  end

  def user_params
    params.require(:user).permit(:email, :password, :admin, :alias, :god_mode, :seo_specialist)
  end
end
