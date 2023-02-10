require 'sinatra'
require 'sinatra/reloader'
require 'pp'
require 'sqlite3'

get('/') do
  db = SQLite3::Database.new('db/game_collection.db')
  db.results_as_hash = true
  amount = db.execute('SELECT * FROM games').count
  slim(:start, locals:{amount:amount})
end

get('/database') do
  db = SQLite3::Database.new('db/game_collection.db')
  db.results_as_hash = true

  begin
    whatgames
  rescue NameError
    games = db.execute('SELECT * FROM games ORDER BY title')
  else
    case whatgames
    when 'all'
      games = db.execute('SELECT * FROM games ORDER BY title')
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
  db = SQLite3::Database.new('db/game_collection.db')
  db.results_as_hash = true
  games = db.execute('SELECT * FROM games ORDER BY title')
  consoles = db.execute('SELECT * FROM consoles')
  game_genres = []
  games.each do |game|
    array = []
    array << game['id']
    genres = db.execute('SELECT genre_id FROM game_genres WHERE game_id = ?', game['id'])
    stringinarray = ""
    genres.each do |genre|
      stringinarray << genre['genre_id'].to_s + " "
    end
    array << stringinarray.chomp(' ')
    game_genres << array
  end
  game_genres = game_genres.to_h
  slim(:'games/editpage', locals:{games:games, consoles:consoles, game_genres:game_genres})
end


get('/database/new') do
  db = SQLite3::Database.new('db/game_collection.db')
  db.results_as_hash = true
  consoles = db.execute('SELECT * FROM consoles')
  slim(:'games/new', locals:{consoles:consoles})
end

get('/database/:id') do
  id = params[:id]
  db = SQLite3::Database.new('db/game_collection.db')
  db.results_as_hash = true
  game = db.execute('SELECT * FROM games WHERE id = ?', id).first
  console = db.execute('SELECT * FROM consoles WHERE id = ?', game['console_id']).first
  db.results_as_hash = false
  genre_ids = db.execute('SELECT genre_id FROM game_genres WHERE game_id = ?', id)
  genres = ""
  genres << db.execute('SELECT name FROM genres WHERE id = ?', genre_ids[0]).first.first

  if genre_ids.count > 2
    genre_ids[1...-1].each do |genre_id|
      genres << ', ' + db.execute('SELECT name FROM genres WHERE id = ?', genre_id).first.first
    end
  end

  unless genre_ids.count == 1
    genres << ' and '
    genres << db.execute('SELECT name FROM genres WHERE id = ?', genre_ids[-1]).first.first
  end

  genres = genres.chomp(' ')
  p genres
  slim(:'games/show', locals:{game:game, console:console, genres:genres})
end

post('/database/:id/update') do
  id = params[:id].to_i
  title = params[:title].chomp(' ')
  release_year = params[:release_year].chomp(' ')
  console_id = params[:console_id].chomp(' ')
  part_of_series = params[:part_of_series].chomp(' ')
  genres = params[:genres].split(' ')
  db = SQLite3::Database.new('db/game_collection.db')
  db.results_as_hash = true
  db.execute('UPDATE games SET title=?, release_year=?, console_id=?, part_of_series=? WHERE id=?', title, release_year, console_id, part_of_series, id)
  db.execute('DELETE FROM game_genres WHERE game_id=?', id)
  genres.each do |genre|
    db.execute('INSERT INTO game_genres (game_id, genre_id) VALUES (?,?)', id, genre)
  end
  redirect('/database/edit')
end

post('/database/new') do
  title = params[:title].chomp(' ')
  release_year = params[:release_year].chomp(' ')
  console_id = params[:console_id].chomp(' ')
  part_of_series = params[:part_of_series].chomp(' ')
  genres = params[:genres].split(' ')
  db = SQLite3::Database.new('db/game_collection.db')
  id = db.execute('SELECT MAX(id) FROM games')[0][0] + 1
  db.results_as_hash = true
  genres.each do |genre|
    db.execute('INSERT INTO game_genres (game_id, genre_id) VALUES (?,?)', id, genre)
  end
  db.execute('INSERT INTO games (title, release_year, console_id, part_of_series) VALUES (?,?,?,?)', title,release_year, console_id, part_of_series)
  redirect('/database')
end
