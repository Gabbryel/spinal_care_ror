Rails.application.routes.draw do
  get 'admin/main'
  devise_for :users
  root to: "pages#home"

  get 'admin', to: 'admin#main', constraints: { subdomain: 'admin' }
end
