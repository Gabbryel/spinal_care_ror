module ApplicationHelper
  def dashboard_page_helper
    current_page?(dashboard_path) || current_page?(dashboard_personal_path) || current_page?(dashboard_profesii_path)
  end
end
