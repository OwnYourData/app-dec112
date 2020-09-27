Rails.application.routes.draw do
	scope "(:locale)", :locale => /en|de/ do
		root  'pages#index'
		get   'favicon',    to: 'pages#favicon'
		match '/info',      to: 'pages#index',     via: 'get'
		match '/info',      to: 'pages#index',     via: 'post'
		match '/error',     to: 'pages#error',     via: 'get'
		match '/password',  to: 'pages#password',  via: 'get'
		match '/write',     to: 'pages#write',     via: 'post'
	end
end
