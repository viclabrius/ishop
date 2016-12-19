# encoding: UTF-8

# gem install sinatra
# gem install sqlite3
# gem install sinatra-contrib

require 'sinatra'
require 'sqlite3'
require 'digest/md5'
require "sinatra/reloader" if development?

# Установка порта на котором слушает запросы веб-сервер и приложение
# В данном случае он слушает на 5000 порту и адрес будет http:/localhost:5000
set :port, ENV["PORT"] || 5000

# блок конфигурации, вызывается при старте приложения
configure do
  enable :sessions
end

database = SQLite3::Database.new( "db/products.db3" )

before do
    request.path_info.sub! %r{/$}, ''
    @site_layout = :'layout'
    t=database.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='products'")
    if t.length > 0 then
      database.results_as_hash = true
      @categories = database.execute( "select * from categories" )
    else
      @categories =[]
    end
    @products=[]
end

not_found do
      status 404
      @msg="Такой <b>страницы не существует</b>! Проверьте правильность запроса"
      @linkback=request.referer||"/"
      @linkbacktxt="Назад"
      erb :message, :layout => @site_layout
end

helpers do
  def protected?
    session['userid'] && session['userid'] == "admin"
  end
  def protected!
    redirect '/login' unless protected?
  end
  def authorized?
    session['userid']
  end
  def authorize!
    redirect '/login' unless authorized?
  end

end

get "/initdb" do
  t=database.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='products'")
  unless t.length > 0 then
    database.execute("CREATE TABLE IF NOT EXISTS products (`product_id`  INTEGER PRIMARY KEY, `category_id`  INTEGER, `name`  TEXT, `description` TEXT, `image` TEXT, `count` INTEGER, `price` REAL)")
    database.execute("CREATE TABLE IF NOT EXISTS `users` (`user_id`  INTEGER PRIMARY KEY, `username`  TEXT, `email` TEXT, `password`  TEXT)")
    database.execute("CREATE TABLE IF NOT EXISTS `categories` (`category_id`  INTEGER PRIMARY KEY, `category`  TEXT)")
    database.execute("CREATE TABLE IF NOT EXISTS `carts` (`cart_id`  INTEGER PRIMARY KEY, `user_id`  INTEGER, `product_id` INTEGER, `cookies` TEXT, `count` INTEGER, `datetime`  INTEGER,  `payinfo` TEXT)")
    #  insert values
    database.execute("INSERT INTO `categories` (category_id,category) VALUES (1,'гирлянды'), (2,'стеклянные игрушки'), (3,'ёлки')")
    database.execute("INSERT INTO `users` (user_id,username,email,password) VALUES (1,'admin','admin@localhost','admin'), (2,'user','user@test.ru','user')")
    database.execute("INSERT INTO `products` VALUES (1,3,'Елка вечнозеленая','высота 2 метра,страна Россия,возраст 9 лет повышенной пушистости','elka.jpg',20,1345.0)")
    database.execute("INSERT INTO `products` VALUES (2,2,'Шар расписной','Стеклянная игрушка в виде шара. Ручная роспись вологодских мастеров яркими новогодними узорами.','sharvologodsky.png',5,500.0)")
    database.execute("INSERT INTO `products` VALUES (3,1,'Гирлянда на елку блестящая','Гирлянда выполнена в виде блестящих колец. Придает елке нарядный праздничный вид.','girlyandakoltso.jpg',15,745.0)")
    database.execute("INSERT INTO `products` VALUES (4,2,'Макушка на елку','Самая важная деталь новогоднего украшения елки - это украшение макушки елки. Данный товар придаст вашей елке уникальный праздничный вид. ','makushka.png',10,1020.0)")
  end
end

["/admin","/admin/:id"].each do |path|
  get path do
    protected!
    database.results_as_hash = true
    @products = database.execute( "SELECT categories.category,products.* FROM categories JOIN products ON categories.category_id = products.category_id" )
    erb :admin, :layout=> @site_layout
  end
end

post '/admin' do
  protected!
  if params[:action] == "newcategory" && params[:category] !=""
    categories = database.execute("SELECT category FROM `categories` WHERE category='#{params[:category]}'")
    if categories.length == 0
      database.execute("INSERT INTO `categories` (category) VALUES ('"+params[:category]+"')")
    end
  end

  if params[:action] == "delcategory" && params[:category] != ""
    products = database.execute("SELECT category_id FROM `products` WHERE category_id='#{params[:category]}'")
    unless products.length > 0
      database.execute("DELETE FROM `categories` WHERE category_id='"+params[:category]+"'")
    end
  end

  if params[:action] =="add" && !params[:name].nil? && !params[:category].nil? && !params[:image].nil? && !params[:count].nil? && !params[:price].nil?
    file_name=""
    if params[:image] != nil
      file_name=params[:image][:filename]
      file_name=Digest::MD5.hexdigest(rand(10000000).to_s).slice(0, 20)+"."+params[:image][:type].split('/')[1]
      File.open(Dir.pwd+"/public/shopimages/"+file_name,"wb") { |f| f.write(params[:image][:tempfile].read)}
    end
    database.execute("INSERT INTO `products` (category_id,name,description,image,count,price) VALUES ('#{params[:category]}','#{params[:name]}','#{params[:description]}','#{file_name}','#{params[:count]}','#{params[:price]}')")
  end

  if params[:action] == "delproduct"
    database.results_as_hash = true
    products=database.execute("SELECT image FROM `products` WHERE product_id='#{params[:product]}'")
    if products.length > 0
      if File.file?(Dir.pwd+"/public/shopimages/"+products[0]['image']) && products[0]['image'] != ""
        File.delete(Dir.pwd+"/public/shopimages/"+products[0]['image'])
      end
    end
    database.execute("DELETE FROM `products` WHERE product_id='#{params[:product]}'")
  end
  redirect "/admin"
end

get "/" do
  database.results_as_hash = true
  t=database.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='products'")
  if t.length > 0 then
    database.results_as_hash = true
    # делаемм sql запрос с объединением полей из двух таблиц categories и products
    @products = database.execute( "SELECT categories.category,products.* FROM categories JOIN products ON categories.category_id = products.category_id" )
  else
    @products =[]
  end
  erb :index, :layout=> @site_layout
end

get "/viewpurchases" do
  protected!
  @db=database.execute("SELECT products.product_id,products.name,products.price,carts.count,carts.datetime,categories.category,users.username FROM `products`,`carts`,`categories`,`users` WHERE products.product_id=carts.product_id AND products.category_id=categories.category_id AND carts.user_id=users.user_id ORDER by datetime desc")
  erb :viewpurchases, :layout=> @site_layout
end

get "/login" do
  # если еще не авторизованы
  unless authorized?
    erb :login, :layout=> @site_layout
  else
    # иначе сообщаем, что авторизованы
    @msg="Вы запросили страницу авторизации, но Вы <b>уже авторизованы</b> под именем '<b>#{session['userid']}</b>'"
    @linkback="/"
    @linkbacktxt="Выход"
    erb :message, :layout => @site_layout
  end
end

get "/logout" do
  session['userid'] = nil
  session['cart'] = nil
  session.clear
  redirect "/"
end

get "/preview/:id" do
  database.results_as_hash = true
  @products=database.execute("SELECT product_id,name,image FROM products WHERE product_id='#{params[:id]}'")
  erb :preview, :layout=> @site_layout
end

["/logincheck","/login"].each do |path|
  post path do
      database.results_as_hash = true
      users = database.execute( "SELECT * FROM users WHERE username='#{params[:username]}'" );
      if users.length >0 && users[0]['password'] == params[:password]
        session['userid']=params[:username]
        @msg="Авторизация пользователя <b>#{params[:username]}</b> прошла успешно"
        @linkback="/"
        @linkbacktxt="Выход"
      else
        session['userid']=nil
        @msg="Пользователь <b>#{params[:username]}</b> не существует, <a href='/register'>зарегистрируйтесь</a> или..."
        @linkback=request.referer||"/"
        @linkbacktxt="попробуйте войти еще раз"
      end
      erb :message, :layout => @site_layout
  end
end

get "/register" do
  erb :registration, :layout => @site_layout
end

post "/register" do
  unless params[:username].nil? && params[:password].nil? && params[:email].nil?
    database.results_as_hash = true
    db=database.execute("SELECT username FROM users WHERE username='#{params[:username]}'")
    if db.length >0
      @msg="Такой пользователь <b>#{params[:username]}<b> уже зарегистрирован!!!"
      @linkback=request.referer||"/"
      @linkbacktxt="Попровать еще раз?"
    else
      session['userid']=params[:username]
      database.execute("INSERT INTO `users` (username,email,password) VALUES ('#{params[:username]}','#{params[:email]}','#{params[:password]}')")
      @msg="Поздравляем!!! Пользователь '<b>#{params[:username]}</b>' успешно зарегистрирован"
      @linkback="/login"
      @linkbacktxt="Войти?"
    end
    erb :message, :layout => @site_layout
  end
end

get "/cart" do
  authorize!
  query=""
  unless session['cart'].nil?
    # берем массив ключей хеша покупок из сессионной корзины и заменяем кавычки ", которыми уже окружены имена ключей хеша, на одинарные '
    query=session['cart'].keys.inspect[1...-1].gsub('"',"'")
  end
  database.results_as_hash = true
  @products=database.execute("SELECT product_id,name,price FROM products WHERE product_id IN (#{query})")
  erb :cart
end

get "/cart/:id" do
  authorize!
  if session['cart'].nil?
    session['cart'] = {}
  end
  if session['cart'].has_key?(params[:id])
    database.results_as_hash = true
    db=database.execute("SELECT count FROM `products` WHERE product_id='#{params[:id]}'")
    if session['cart'][params[:id]] < db[0]['count']
      session['cart'][params[:id]]+=1
      redirect request.referer||"/"
    else
      @msg="Больше нельзя добавить этот товар в корзину, т.к. вы достигли его доступного количества"
      @linkback=request.referer
      @linkbacktxt="Вернуться назад"
      erb :message, :layout=> @site_layout
    end
  else
    session['cart'][params[:id]]=1
    redirect request.referer||"/"
  end
end

get "/cart/:id/:action" do
  authorize!
  case params[:action]
    when "delete"
        session['cart'].delete(params[:id])
        if session['cart'].length == 0
          session['cart'] = nil
        end
        redirect "/cart"
    when "plus"
        database.results_as_hash = true
        db=database.execute("SELECT count FROM `products` WHERE product_id='#{params[:id]}'")
        if session['cart'][params[:id]] < db[0]['count']
          session['cart'][params[:id]]=session['cart'][params[:id]]+1
          redirect "/cart"
        else
          @msg="Нельзя увеличивать количество товара, т.к. вы достигли его доступного количества"
          @linkback=request.referer
          @linkbacktxt="Вернуться назад"
          erb :message, :layout=> @site_layout
        end
    when "minus"
      unless session['cart'][params[:id]] <= 1
        session['cart'][params[:id]]-=1
      else
        session['cart'].delete(params[:id])
        if session['cart'].length == 0
          session['cart'] = nil
        end
      end
      redirect "/cart"
    when "empty"
        session['cart'] = nil
        redirect "/cart"
  end
end

# индивидуальные покупки пока не предусмотрены, так что пока редирект на Корзину
["/buy","/buy/:id"].each do |path|
  get path do
    if !params[:id].nil?
      redirect "/cart/#{params[:id]}"
    end
    redirect "/cart"
  end
end

post '/buy' do
  authorize!
  if !params[:visa].nil? && !session['cart'].nil?
    time=Time.now.to_i
    session['cart'].each do |key,value|
      database.execute("UPDATE `products` SET count = count - #{value} WHERE product_id ='#{key}'")
      database.results_as_hash = true
      db=database.execute("SELECT user_id FROM `users` WHERE username='#{session['userid']}'")
      database.execute("INSERT INTO `carts` (user_id,product_id,cookies,count,datetime,payinfo) VALUES('#{db[0]['user_id']}','#{key}','#{session['session_id']}','#{value}','#{time}','#{params[:visa]+" + "+params[:cvv]}')")
    end
    # берем массив ключей хеша покупок из сессионной корзины и заменяем кавычки ", которыми уже окружены имена ключей хеша, на одинарные '
    query=session['cart'].keys.inspect[1...-1].gsub('"',"'")
    database.results_as_hash = true
    db=database.execute("SELECT SUM(products.price*carts.count) as sum FROM `products`,`carts` WHERE products.product_id IN (#{query}) AND products.product_id=carts.product_id AND carts.datetime='#{time}' AND cookies='#{session['session_id']}'")
    session['cart'] = nil
    @msg="Поздравляем! Покупка на сумму <b>#{db[0]['sum']}</b> успешно завершена. Товар будет доставлен по указанному адресу или мы свяжемся с вами по телефону!!!"
    @linkback=request.referer||"/"
    @linkbacktxt="Вернуться назад"
    erb :message, :layout => @site_layout
  else
    erb :buy, :layout=> @site_layout
  end
end

get '/product/:id' do
  database.results_as_hash = true
  query="SELECT categories.category,products.* FROM categories JOIN products ON categories.category_id = products.category_id WHERE products.product_id='#{params['id']}'"
  @products=database.execute(query)
  database.results_as_hash = false
  erb :productinfo, :layout=> @site_layout
end

get '/categories/:id' do
  database.results_as_hash = true
  query="SELECT categories.category,products.* FROM categories JOIN products ON categories.category_id = products.category_id WHERE products.category_id='#{params['id']}'"
  @products=database.execute(query)
  database.results_as_hash = false
  erb :index, :layout=> @site_layout
end
