# Dashboard pages under the admin/ namespace: admins only. Pundit's checks are
# skipped for admin/* controllers (ApplicationController#skip_pundit?), so
# access is enforced here. SEO specialists go to the analytics, like on every
# other dashboard page.
module Admin
  class BaseController < ApplicationController
    layout "dashboard"

    before_action :require_admin

    private

    def require_admin
      return if current_user&.admin
      return redirect_to(dashboard_analytics_path) if current_user&.analytics_only?

      render inline: "<%= render 'shared/no_access' %>", layout: "dashboard", status: :forbidden
    end
  end
end
