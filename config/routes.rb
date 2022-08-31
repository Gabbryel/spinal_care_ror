Rails.application.routes.draw do
  get 'specialties/new'
  get 'specialties/create'
  get 'specialties/edit'
  get 'specialties/update'
  get 'specialties/index'
  get 'specialties/show'
  get 'specialties/destroy'
  get 'professions/new'
  get 'professions/create'
  get 'professions/edit'
  get 'professions/update'
  get 'professions/index'
  get 'professions/show'
  get 'professions/destroy'
  get 'profession/new'
  get 'profession/create'
  get 'profession/edit'
  get 'profession/update'
  get 'profession/index'
  get 'profession/show'
  get 'profession/destroy'
  root to: "pages#home"
  devise_for :users
  resources :reviews
  resources :members
  resources :professions
  resources :specialties

  get 'dashboard', to: 'admin#dashboard'
  get 'dashboard/personal', to: 'admin#personal'
  get 'dashboard/profesii', to: 'admin#professions'
end
