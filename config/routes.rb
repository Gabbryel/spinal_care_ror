Rails.application.routes.draw do
  resources :users, only: %i[edit update]
  root to: "pages#home"
  devise_for :users
  resources :reviews
  resources :members
  resources :professions
  resources :specialties
  get 'specialitati-medicale', to: 'specialties#all_specialties'
  get 'specialitati-medicale/:id', to: 'specialties#about'

  get 'dashboard', to: 'admin#dashboard'
  get 'dashboard/personal', to: 'admin#personal'
  get 'dashboard/profesii', to: 'admin#professions'
end
