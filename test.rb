require 'SQLite3'

db = SQLite3::Database.new("db/game_collection.db")

db.results_as_hash = true
p db.execute('SELECT * FROM genres')