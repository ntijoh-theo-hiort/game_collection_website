require 'sinatra'
require 'sinatra/reloader'
require 'pp'
require 'sqlite3'
require 'bcrypt'
require_relative 'model/model.rb'
enable :sessions
include Model

# redirects to /error if you're not logged in and trying to access certain pages
before do 
  if request.request_method == 'GET'
    if session[:whosloggedin] == nil && request.path != '/login' && request.path != '/' && request.path != '/error'
      session[:error_text] = "You can't access this page unless you're logged in. Click back to go to the login page."
      session[:error_redirect] = '/login'
      redirect('/error')
    end
  end
end

# Display Landing Page
#
# @see Model#all_games
get('/') do
  amount = Model.all_games.count
  slim(:start, locals:{amount:amount})
end

# Displays list of links to all games in database
#
# @see Model#all_games
get('/database') do
  games = Model.all_games
  slim(:'games/index', locals:{games:games})
end

# Displays list of all games in database along with forms for editing their attributes
#
# @see Model#username_is_admin?
# @see Model#all_games
# @see Model#all_consoles
# @see Model#all_genres
# @see Model#genres_of_game_by_id
get('/database/edit') do
  if Model.username_is_admin?(session[:whosloggedin]) == false
    session[:error_text] = 'This page is only accessible for admin users'
    session[:error_redirect] = '/'
    redirect('/error')
  end

  games = Model.all_games
  consoles = Model.all_consoles
  genres = Model.all_genres

  game_genres = []      
  games.each do |game|    
    array = []
    array << game['id']
    genres_of_current_game = Model.genres_of_game_by_id(game['id'])
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

# Displays form for entering a new game into the database
#
# @see Model#username_is_admin?
# @see Model#all_consoles
# @see Model#all_genres
get('/database/new') do

  if Model.username_is_admin?(session[:whosloggedin]) == false
    session[:error_text] = 'This page is only accessible for admin users'
    session[:error_redirect] = '/'
    redirect('/error')
  end

  consoles = Model.all_consoles
  genres = Model.all_genres

  slim(:'games/new', locals:{consoles:consoles, genres:genres})
end

# Displays some information about the selected game and an image of renowned programmer Theo Hiort holding that game.
# Also has a comment form where any user can submit their comments which are shown underneath the form.
#
# @param [String] :id, the ID of the game
# @see Model#game_hash_by_id
# @see Model#console_hash_by_game_id
# @see Model#genres_of_game_by_id
# @see Model#genre_name_by_id
# @see Model#comments_by_game_id
# @see Model#username_by_comment_id
get('/database/:id') do
  id = params[:id]
  game = Model.game_hash_by_id(id)
  console = Model.console_hash_by_game_id(id)
  genre_ids = Model.genres_of_game_by_id(id)
  genres = ""
  genres << Model.genre_name_by_id(genre_ids[0].to_i)
  whosloggedin = session[:whosloggedin]

  if genre_ids.count > 2
    genre_ids[1...-1].each do |genre_id|
      genres << ', ' + Model.genre_name_by_id(genre_id)
    end
  end

  if genre_ids.count == 1
    genre_or_genres = "genre"
  else
    genres << ' and '
    genres << Model.genre_name_by_id(genre_ids[-1])
    genre_or_genres = "genres"
  end

  genres = genres.chomp(' ')
  

  comments = Model.comments_by_game_id(id)

  if comments.length > 0
    comments.map{|comment| comment["username"] = Model.username_by_comment_id(comment["id"])}
  end  

  imgpath = "/img/#{id}.jpg"
  slim(:'games/show', locals:{game:game, console:console, genres:genres, imgpath:imgpath, genre_or_genres:genre_or_genres, comments:comments, id:id, whosloggedin:whosloggedin})
end

# Simple login and account creation page
get('/login') do
  slim(:login, locals:{whosloggedin:session[:whosloggedin]})
end

# Error page. Displays unique error message depending on where the error was detected.
get('/error') do
  if session[:error_text] == nil
    redirect('/')
  end

  slim(:error, locals:{error_text:session[:error_text], error_redirect:session[:error_redirect]})
end

# If no other routes match, you will automatically land on this one. Only works when logged in, 
# as entering any route other than accepted ones while not logged in will display an error message
# telling you to log in. This is intended behavior since users who don't want to create an account
# don't deserve to see the beautiful 404 page.
get('/:four_oh_four') do
  slim(:four_oh_four)
end

# Submits a comment into the database along with the current user's id, the game's id and its own unique comment id.
#
# @param [String] :id, the ID of the game
# @param [String] content, the content of the comment
# @see Model#user_id_by_username
# @see Model#add_comment
post('/:id/writecomment') do
  if session[:whosloggedin] == nil 
    redirect('/')
  end

  id = params[:id]

  content = params[:content]
  username = session[:whosloggedin]
  user_id = Model.user_id_by_username(username)
  Model.add_comment(params[:content], user_id, id)
  

  redirect("/database/#{id}")
end

# Deletes a comment from the database. The delete button is not displayed for comments which you don't own.
#
# @param [String] :id, the ID of the game
# @param [String] :comment_id, the ID of the comment
# @see Model#delete_comment
post('/:id/deletecomment/:comment_id') do
  if session[:whosloggedin] == nil 
    redirect('/')
  end

  game_id = params[:id]
  comment_id = params[:comment_id]
  Model.delete_comment(comment_id)

  redirect("/database/#{game_id}")
end

# Updates a game's attributes. This route is called from the get route /database/edit.
#
# @param [String] :id, the ID of the game
# @param [String] :title, the title of the game as written into the form
# @param [String] :release_year, the release year of the game as written into the form
# @param [String] :console_id, the id of the console the game belongs to as written into the form
# @param [String] :part_of_series, can be "Yes" or "No" depending on if the game is part of a series of games. Think of it like a boolean except SQL doesn't give you shit.
# @param [String] :genres, the ids of the genres the game belongs to, separated by spaces
# @see Model#update_game
# @see Model#game_genres_delete_all_by_game_id
# @see Model#game_genres_insert_new
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

  Model.update_game(title, release_year, console_id, part_of_series, id)
  Model.game_genres_delete_all_by_game_id(id)
  genre_ids.each do |genre_id|
    Model.game_genres_insert_new(id, genre_id)
  end
  redirect('/database/edit')
end

# Deletes a game from the database. This route is called from the get route /database/edit.
#
# @param [String] :id, the ID of the game
# @see Model#delete_game
post('/database/:id/delete') do
  Model.delete_game(params[:id])
  redirect('/database/edit')
end

# Inserts a new game into the database. This route is called from the get route /database/new.
#
# @param [String] :title, the title of the game as written into the form
# @param [String] :release_year, the release year of the game as written into the form
# @param [String] :console_id, the id of the console the game belongs to as written into the form
# @param [String] :part_of_series, can be "Yes" or "No" depending on if the game is part of a series of games. Think of it like a boolean except SQL doesn't give you shit.
# @param [String] :genres, the ids of the genres the game belongs to, separated by spaces
# @see Model#create_id_for_new_game
# @see Model#add_game_genres
# @see Model#insert_into_new_game
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

  id = Model.create_id_for_new_game
  genres.each do |genre|
    Model.add_game_genres(id, genre)
  end
  Model.insert_into_new_game(id, title, release_year, console_id, part_of_series)
  redirect('/database')
end

# Creates a new user depending on if the password is acceptable and username isn't already taken. This route is called from the get route /login.
#
# @param [String] username, the username taken from the "username" box in the login.slim createaccount form.
# @param [String] password, the unencrypted password taken from the "password" box in the login.slim createaccount form.
# @param [String] passwordconfirm, the unencrypted password taken from the "confirm password" box in the login.slim createaccount form.
# @see Model#username_is_unique?
# @see Model#create_account
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
  elsif password !~ /^(?=.*\d)(?=.*[[:punct:]])(?=.*[[:upper:]]).*$/ || password.length < 8
    session[:error_text] = "invalid login: password must be longer than 8 symbols and contain at least one digit, one capital letter, and one special character"
    session[:error_redirect] = '/login'
    redirect('/error')
  elsif Model.username_is_unique?(username) == false
    session[:error_text] = "invalid login: a user with that name already exists"
    session[:error_redirect] = '/login'
    redirect('/error')
  end

  pwdigest = BCrypt::Password.create(password)
  Model.create_account(username, pwdigest)
  session[:whosloggedin] = username
  redirect('/login')
end

# Sets the session variable "whosloggedin" to your username if you enter the right password for an existing username.
#
# @param [String] username, the username taken from the "username" box in the login.slim login form.
# @param [String] password, the unencrypted password taken from the "password" box in the login.slim login form.
# @param [String] passwordconfirm, the unencrypted password taken from the "confirm password" box in the login.slim login form.
# @see Model#username_is_unique
# @see Model#pwdigest_by_user
post('/login') do
  username = params[:username]
  password = params[:password]
  if Model.username_is_unique?(username) == false
    pwdigest = Model.pwdigest_by_user(username)
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

# Sets the session variable "whosloggedin" to nil.
post('/logout') do
  session[:whosloggedin] = nil
  redirect('/login')
end