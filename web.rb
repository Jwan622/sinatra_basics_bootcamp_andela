require 'sinatra'
require 'data_mapper'
require 'bcrypt'
require 'sinatra/flash'
require 'sinatra/partial'
require 'json'

set :partial_template_engine, :erb
enable :partial_underscores

enable :sessions
set :session_secret, '*&(^B234'

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/todo_list.db")

class Item
  include DataMapper::Resource
  property :id, Serial
  property :content, Text, :required => true
  property :done, Boolean, :required => true, :default => false
  property :created, DateTime
  belongs_to :user
end

class User
  include DataMapper::Resource
  property :id, Serial
  property :username, Text, :required => true
  property :password, Text, :required => true
  property :salt, Text, :required => true
  property :created_at, DateTime
  has n, :items
end

DataMapper.finalize.auto_upgrade!

helpers do
  def login?
    if session[:username].nil?
      return false
    else
      return true
    end
  end

  def username
    return session[:username]
  end
end

get '/' do
  user = User.first(:username => username)
  if user
    @items = User.first(:username => username).items
    erb :index
  else
    @items = []
    erb :index
  end
end

get '/new' do
  if !username
    flash[:error] = "You need to login first. Nice try hacker."
    redirect "/"
  else
    @title = "Add todo item"
    erb :new
  end
end

post '/new' do
  if !username
    flash[:error] = "You need to login first. Nice try hacker."
    redirect "/"
  else
    user = User.first(:username => username)
    user.items << Item.create(:content => params[:content], :created => Time.now)
    user.items.save
    redirect '/'
  end
end

post '/done' do
  item = Item.first(:id => params[:id].to_i)
  item.done = !item.done
  item.save
  content_type 'application/json'
  value = item.done ? 'done' : 'not done'
  { :id => params[:id], :status => value }.to_json
end

get '/delete/:id' do
  @item = Item.first(:id => params[:id].to_i)
  erb :delete
end

delete '/delete/:id' do
  if params.has_key?("ok")
    item = Item.first(:id => params[:id].to_i)
    item.destroy
    redirect '/'
  else
    redirect '/'
  end
end

get "/signup" do
  erb :signup
end

post "/signup" do
  password_salt = BCrypt::Engine.generate_salt
  password_hash = BCrypt::Engine.hash_secret(params[:password], password_salt)
  User.create(:username => params[:username], :password => password_hash, :salt => password_salt)
  session[:username] = params[:username]
  redirect "/"
end

post "/login" do
  user = User.first(:username => params[:username])
  if user && user[:password] == BCrypt::Engine.hash_secret(params[:password], user[:salt])
    session[:username] = params[:username]
    redirect "/"
  end
  erb :error
end

get "/logout" do
  session[:username] = nil
  redirect "/"
end
