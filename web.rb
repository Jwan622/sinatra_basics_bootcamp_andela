require 'sinatra'
require 'data_mapper'
require 'bcrypt'

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/todo_list.db")

#this explains what the Dir.pwd is doing in the DataMapper setup.
puts "#{Dir.pwd}"

class Item
  include DataMapper::Resource
  property :id, Serial
  property :content, Text, :required => true
  property :done, Boolean, :required => true, :default => false
  property :created, DateTime
end

class User
  include DataMapper::Resource
  property :id, Serial
  property :username, Text, :require => true
  property :password, Text, :require => true
  property :created_at, DateTime
end

DataMapper.finalize.auto_upgrade!

enable :sessions
userTable = {}

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
  @items = Item.all(:order => :created.desc)
  redirect '/new' if @items.empty?
  erb :index
end

get '/new' do
  @title = "Add todo item"
  erb :new
end

post '/new' do
  Item.create(:content => params[:content], :created => Time.now)
  redirect '/'
end

post '/done' do
  item = Item.first(:id => params[:id])
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
  user = User.find(:username => params[:username])
  if user && user[:password] == BCrypt::Engine.hash_secret(params[:password], user[:salt])
    session[:username] = params[:username]
    redirect "/"
  end
  haml :error
end

get "/logout" do
  session[:username] = nil
  redirect "/"
end
