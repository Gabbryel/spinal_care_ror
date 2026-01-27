Rails.application.routes.draw do

  get 'dashboard', to: 'admin#dashboard'
  get 'dashboard/analytics', to: 'admin#analytics'
  get 'dashboard/analytics/daily_chart', to: 'admin#analytics_daily_chart'
  get 'dashboard/analytics/geography', to: 'admin#analytics_geography'
  get 'dashboard/analytics/sources', to: 'admin#analytics_sources'
  get 'dashboard/analytics/pages', to: 'admin#analytics_pages'
  get 'dashboard/analytics/user_journey', to: 'admin#analytics_user_journey'
  get 'dashboard/analytics/content', to: 'admin#analytics_content'
  get 'dashboard/analytics/debug', to: 'admin#analytics_debug'
  get 'dashboard/audit', to: 'admin#audit'
  get 'dashboard/users', to: 'admin#edit_users'
  get 'dashboard/personal', to: 'admin#personal'
  get 'dashboard/profesii', to: 'admin#professions', as: 'admin_professions'
  get 'dashboard/specialitati', to: 'admin#specialties', as: 'admin_specialties'
  get 'dashboard/servicii-medicale', to: 'admin#medical_services', as: 'admin_medical_services'
  get 'dashboard/servicii-medicale/:id', to: 'admin#specialty_admin', as: 'admin_specialty'

  get 'dashboard/info-pacient', to: 'admin#info_pacient'
  get 'dashboard/consum-medicamente', to: 'admin#medicines_consumption'

  resources :medicines_consumptions, only: %i[create update destroy]


  resources :facts, except: %i[show]
  get 'info-pacient/:id', to: 'facts#show'
  
  devise_for :users

  resources :users, only: %i[edit update destroy]
  root to: "pages#home"
  resources :reviews
  resources :members, except: %i[show]
  resources :professions
  resources :specialties
  get 'info-pacient-index', to: 'pages#pacient_page'
  get 'specialitati-medicale', to: 'specialties#all_specialties'
  get 'specialitati-medicale/:id', to: 'specialties#about'
  get '/echipa', to: 'pages#medical_team'
  get '/echipa/:id', to: 'members#show', as: 'colectiv'
  get '/consum', to: 'pages#consum'
  resources :medical_services, except: %i[index show]
  get 'servicii-medicale', to: 'medical_services#index'
  get 'servicii-medicale/:id', to: 'medical_services#show_by_specialty'

  get "*any", to: "errors#not_found", via: :all
  get "/500", to: "errors#internal_server_error", via: :all
end
