Rails.application.routes.draw do
  resources :users, only: %i[edit update]
  root to: "pages#home"
  devise_for :users
  resources :reviews
  resources :members, except: %i[show]
  resources :professions
  resources :specialties
  get 'specialitati-medicale', to: 'specialties#all_specialties'
  get 'specialitati-medicale/:id', to: 'specialties#about'
  get '/echipa', to: 'pages#medical_team'
  get '/echipa/:id', to: 'members#show'
  resources :medical_services, except: %i[index show]
  get 'servicii-medicale', to: 'medical_services#index'
  get 'servicii-medicale/:id', to: 'medical_services#show'

  get 'dashboard', to: 'admin#dashboard'
  get 'dashboard/personal', to: 'admin#personal'
  get 'dashboard/profesii', to: 'admin#professions'

  get "*any", to: "errors#not_found", via: :all
  get "/500", to: "errors#internal_server_error", via: :all
end
