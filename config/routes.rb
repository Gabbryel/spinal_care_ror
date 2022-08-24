Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"
  resources :persons

  get 'admin', to: 'admin#main'
end
