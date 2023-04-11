require 'sinatra'
require 'sinatra/reloader'
require 'pp'
require 'sqlite3'
require 'bcrypt'
require_relative 'model.rb'
enable :sessions

before do 
  if request.request_method == 'GET'
    if session[:whosloggedin] == nil && request.path != '/login' && request.path != '/' && request.path != '/error'
      session[:error_text] = "You can't access this page unless you're logged in. Click back to go to the login page."
      session[:error_redirect] = '/login'
      redirect('/error')
    end
  end
end

get('/') do
  db = Database.new
  amount = db.all_games.count
  slim(:start, locals:{amount:amount})
end

get('/database') do
  db = Database.new

  begin
    whatgames
  rescue NameError
    games = db.all_games
  else
    case whatgames
    when 'all'
      games = db.all_games
    when 'console'
      p 'yoda'
      games = db.execute('SELECT * FROM games WHERE console_id = ? ORDER BY title', console)
      pp games
    when 'year'
      games = db.execute('SELECT * FROM games WHERE release_year = ? ORDER BY title', year)
    when 'partofseries'
      games = db.execute('SELECT * FROM games WHERE part_of_series? = "Yes" ORDER BY title')
    end
  end
  slim(:'games/index', locals:{games:games})
end

post('/database') do

end

get('/database/edit') do
  db = Database.new
  if db.username_is_admin?(session[:whosloggedin]) == false
    session[:error_text] = 'This page is only accessible for admin users'
    session[:error_redirect] = '/'
    redirect('/error')
  end

  db = Database.new
  games = db.all_games
  consoles = db.all_consoles
  genres = db.all_genres

  game_genres = []      
  games.each do |game|    
    array = []
    array << game['id']
    genres_of_current_game = db.genres_of_game_by_id(game['id'])
    string_of_genres = ""
    genres_of_current_game.each do |genre|
      string_of_genres << genre.to_s + " "
    end
    array << string_of_genres.chomp(' ')
    game_genres << array
  end

  game_genres = game_genres.to_h
  slim(:'games/edit', locals:{games:games, consoles:consoles, game_genres:game_genres, genres:genres})
end


get('/database/new') do
  db = Database.new

  if db.username_is_admin?(session[:whosloggedin]) == false
    session[:error_text] = 'This page is only accessible for admin users'
    session[:error_redirect] = '/'
    redirect('/error')
  end

  consoles = db.all_consoles
  genres = db.all_genres

  slim(:'games/new', locals:{consoles:consoles, genres:genres})
end

get('/database/:id') do
  db = Database.new
  id = params[:id]
  game = db.game_hash_by_id(id)
  console = db.console_hash_by_game_id(id)
  genre_ids = db.genres_of_game_by_id(id)
  genres = ""
  genres << db.genre_name_by_id(genre_ids[0].to_i)

  if genre_ids.count > 2
    genre_ids[1...-1].each do |genre_id|
      genres << ', ' + db.genre_name_by_id(genre_id)
    end
  end

  if genre_ids.count == 1
    genre_or_genres = "genre"
  else
    genres << ' and '
    genres << db.genre_name_by_id(genre_ids[-1])
    genre_or_genres = "genres"
  end


  genres = genres.chomp(' ')
  
  imgpath = "/img/#{id}.jpg"
  slim(:'games/show', locals:{game:game, console:console, genres:genres, imgpath:imgpath, genre_or_genres:genre_or_genres})
end

get('/login') do
  slim(:login, locals:{whosloggedin:session[:whosloggedin]})
end

get('/error') do
  unless defined?(session[:error_text]) && defined?(session[:error_redirect])
    redirect('/')
  end

  slim(:error, locals:{error_text:session[:error_text], error_redirect:session[:error_redirect]})
end

post('/database/:id/update') do
  id = params[:id].to_i
  title = params[:title].chomp(' ')
  release_year = params[:release_year].chomp(' ')
  console_id = params[:console_id].chomp(' ')
  part_of_series = params[:part_of_series].chomp(' ')
  genre_ids = params[:genres].split(' ')

  [title, release_year, console_id, part_of_series, genre_ids].each do |param|
    if param == ''
      session[:error_text] = 'invalid entry: every box must be filled'
      session[:error_redirect] = '/database/edit'
      redirect('/error')
    end
  end

  db = Database.new
  db.update_game(title, release_year, console_id, part_of_series, id)
  db.game_genres_delete_all_by_game_id(id)
  genre_ids.each do |genre_id|
    db.game_genres_insert_new(id, genre_id)
  end
  redirect('/database/edit')
end

post('/database/:id/delete') do
  Database.new.delete_game(params[:id])
  redirect('/database/edit')
end

post('/database/new') do
  title = params[:title].chomp(' ')
  release_year = params[:release_year].chomp(' ')
  console_id = params[:console_id].chomp(' ')
  part_of_series = params[:part_of_series].chomp(' ')
  genres = params[:genres].split(' ')

  [title, release_year, console_id, part_of_series, genres].each do |param|
    if param == ''
      session[:error_text] = 'invalid entry: you must fill in all required boxes'
      session[:error_redirect] = '/database/new'
      redirect('/error')
    end
  end

  db = Database.new
  id = db.create_id_for_new_game
  genres.each do |genre|
    p genre
    db.add_game_genres(id, genre)
  end
  db.insert_into_new_game(id, title, release_year, console_id, part_of_series)
  redirect('/database')
end

post('/createaccount') do
  username = params[:username]
  password = params[:password]
  passwordconfirm = params[:passwordconfirm]

  if password == '' || username == ''
    session[:error_text] = "invalid login: you must fill in all required boxes"
    session[:error_redirect] = '/login'
    redirect('/error')
  elsif password != passwordconfirm
    session[:error_text] = "invalid login: both passwords must match"
    session[:error_redirect] = '/login'
    redirect('/error')
  elsif password !~ /^(?=.*\d)(?=.*[[:punct:]])(?=.*[[:upper:]]).*$/
    session[:error_text] = "invalid login: password must contain at least one digit, one capital letter, and one special character"
    session[:error_redirect] = '/login'
    redirect('/error')
  elsif Database.new.username_is_unique?(username) == false
    session[:error_text] = "invalid login: a user with that name already exists"
    session[:error_redirect] = '/login'
    redirect('/error')
  end

  pwdigest = BCrypt::Password.create(password)
  Database.new.create_account(username, pwdigest)
  session[:whosloggedin] = username
  redirect('/login')
end

post('/login') do
  username = params[:username]
  password = params[:password]
  if Database.new.username_exists(username)
    pwdigest = Database.new.fetch_pwdigest_from_user(username).first.first
    if BCrypt::Password.new(pwdigest) == password
      session[:whosloggedin] = username
      redirect('/login')
    else
      sleep(3)
      session[:error_text] = "invalid login: wrong password for that user"
      session[:error_redirect] = '/login'
      redirect('/error')
    end
  else
    session[:error_text] = "invalid login: no user with that username exists"
    session[:error_redirect] = '/login'
    redirect('/error')
  end
end

post('/logout') do
  session[:whosloggedin] = nil
  redirect('/login')
end