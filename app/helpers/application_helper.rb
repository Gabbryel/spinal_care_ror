module ApplicationHelper
  def path_helper
    request.path.split('/')[1].to_s
  end
  def dashboard_page_helper
    current_page?(dashboard_path) || current_page?(dashboard_personal_path) || current_page?(dashboard_profesii_path) || path_helper == 'professions' || path_helper == 'specialties'
  end

  def access
    current_user && current_user.admin
  end

  def god_mode
    current_user && current_user.god_mode
  end

  def btn_color(u)
    u.admin ? 'btn-red' : 'btn-green'
  end

  def btn_color_god(u)
    u.god_mode ? 'btn-red' : 'btn-green'
  end

  def no_access
    render 'shared/no_access'
  end

  def full_name(member)
    "#{member.first_name} #{member.last_name}"
  end
end
