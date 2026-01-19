class Current < ActiveSupport::CurrentAttributes
  attribute :user, :ip_address, :user_agent, :request_method, :request_path, 
            :controller_name, :action_name, :params, :referer, :request_start_time
end
