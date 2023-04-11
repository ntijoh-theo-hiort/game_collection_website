#SQL commands go here 
class Database
    def initialize
        @db = SQLite3::Database.new('db/game_collection.db')
    end

    def all_games
        @db.results_as_hash = true
        @db.execute('SELECT * FROM games ORDER BY title')
    end

    def all_consoles
        @db.results_as_hash = true
        @db.execute('SELECT * FROM consoles')
    end

    def all_genres
        @db.results_as_hash = true
        @db.execute('SELECT * FROM genres')
    end

    def game_hash_by_id(id)
        @db.results_as_hash = true
        @db.execute('SELECT * FROM games WHERE id = ?', id).first
    end

    def console_hash_by_game_id(id)
        @db.results_as_hash = true
        id = game_hash_by_id(id)['console_id']
        @db.execute('SELECT * FROM consoles WHERE id = ?', id).first
    end

    def genres_of_game_by_id(id)
        @db.results_as_hash = false
        @db.execute('SELECT genre_id FROM game_genres WHERE game_id = ?', id).map{|x| x[0]}
    end

    def genre_name_by_id(id)
        @db.results_as_hash = false
        @db.execute('SELECT name FROM genres WHERE id = ?', id)[0][0]
    end

    def delete_game(id)
        @db.results_as_hash = true
        @db.execute('DELETE FROM games WHERE id=?', id)
        game_genres_delete_all_by_game_id(id)
    end

    def update_game(title, release_year, console_id, part_of_series, id)
        @db.results_as_hash = true
        @db.execute('UPDATE games SET title=?, release_year=?, console_id=?, part_of_series=? WHERE id=?', title, release_year, console_id, part_of_series, id)
    end

    def game_genres_delete_all_by_game_id(id)
        @db.results_as_hash = true
        @db.execute('DELETE FROM game_genres WHERE game_id=?', id)
    end

    def game_genres_insert_new(game_id, genre_id)
        @db.results_as_hash = true
        @db.execute('INSERT INTO game_genres (game_id, genre_id) VALUES (?,?)', game_id, genre_id)
    end

    def create_id_for_new_game
        @db.results_as_hash = true
        @db.execute('SELECT MAX(id) FROM games')[0][0] + 1
    end

    def add_game_genres(id, genre)
        @db.results_as_hash = true
        @db.execute('INSERT INTO game_genres (game_id, genre_id) VALUES (?,?)', id, genre)
    end

    def insert_into_new_game(id, title, release_year, console_id, part_of_series)
        @db.results_as_hash = true
        @db.execute('INSERT INTO games (id, title, release_year, console_id, part_of_series) VALUES (?,?,?,?,?)', id, title, release_year, console_id, part_of_series)
    end

    def username_is_unique?(username)
        @db.results_as_hash = true
        @db.execute('SELECT * from users WHERE username=?', username) == []
    end

    def username_is_admin?(username)
        @db.results_as_hash = false
        @db.execute('SELECT is_admin from users WHERE username=?', username)[0][0] == "Yes"
    end

    def create_account(username, pwdigest)
        @db.results_as_hash = true
        id = @db.execute('SELECT MAX(id) FROM users')[0][0] + 1
        @db.execute('INSERT INTO users (id, username, pwdigest, is_admin) VALUES (?, ?, ?, ?)', id, username, pwdigest, "No")
    end

    def username_exists(username)
        @db.results_as_hash = true
        @db.execute('SELECT * from users WHERE username=?', username).length == 1
    end

    def fetch_pwdigest_from_user(username)
        @db.results_as_hash = false
        @db.execute('SELECT pwdigest from users WHERE username=?', username)
    end
end