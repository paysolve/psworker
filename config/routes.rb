Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
  get '/test_create_payments', to: 'accounts#test_create_payments'
  post '/update', to: 'accounts#update_api'
end
