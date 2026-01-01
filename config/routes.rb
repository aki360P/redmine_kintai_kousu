RedmineApp::Application.routes.draw do
  get 'kintai_kousu', to: 'kintai_kousu#index', as: 'kintai_kousu'
  get 'kintai_kousu/index', to: 'kintai_kousu#index'
  get 'kintai_kousu/show', to: 'kintai_kousu#show', as: 'kintai_kousu_show'
  post 'kintai_kousu/create', to: 'kintai_kousu#create'
  put 'kintai_kousu/:id', to: 'kintai_kousu#update', as: 'kintai_kousu_update'
  patch 'kintai_kousu/:id', to: 'kintai_kousu#update'
  delete 'kintai_kousu/:id', to: 'kintai_kousu#destroy', as: 'kintai_kousu_destroy'
end
