module ApplicationHelper
  def path_helper
    request.path.split('/')[1].to_s
  end
  def dashboard_page_helper
    current_page?(dashboard_path) || current_page?(dashboard_personal_path) || current_page?(dashboard_profesii_path) || path_helper == 'professions'
  end
end
