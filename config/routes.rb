Rails.application.routes.draw do
  get 'reviews/new'
  get 'reviews/create'
  get 'reviews/index'
  get 'reviews/show'
  get 'reviews/edit'
  get 'reviews/update'
  get 'reviews/destroy'
  devise_for :users
  root to: "pages#home"
  resources :persons
  resources :reviews

  get 'admin', to: 'admin#main'
end
