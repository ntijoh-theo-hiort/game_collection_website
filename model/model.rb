#Contains methods with sql commands 
module Model
    @db = SQLite3::Database.new('db/game_collection.db')
    
    # fetches games from database
    #
    # @return [Array] containing hashes with all games and their parameters
    def self.all_games
        @db.results_as_hash = true
        @db.execute('SELECT * FROM games ORDER BY title')
    end

    # fetches consoles from database
    #
    # @return [Array] containing hashes with all consoles and their parameters
    def self.all_consoles
        @db.results_as_hash = true
        @db.execute('SELECT * FROM consoles')
    end

    # fetches genres from database
    #
    # @return [Array] containing hashes with all genre names and ids
    def self.all_genres
        @db.results_as_hash = true
        @db.execute('SELECT * FROM genres')
    end

    # fetches single game from database based on its id
    #
    # @option id [String] the id of a game in the database
    #
    # @return [Hash] containing the parameters for a game
    def self.game_hash_by_id(id)
        @db.results_as_hash = true
        @db.execute('SELECT * FROM games WHERE id = ?', id).first
    end

    # fetches single console from database based on the game_id of a game for that console
    #
    # @option id [String] the id of a game in the database
    # @see Model#console_hash_by_id
    #
    # @return [Hash] containing the parameters for a console
    def self.console_hash_by_game_id(id)
        @db.results_as_hash = true
        id = game_hash_by_id(id)['console_id']
        @db.execute('SELECT * FROM consoles WHERE id = ?', id).first
    end

    # fetches the genres for a game
    #
    # @option id [String] the id of a game in the database
    #
    # @return [Array] containing the ids of genres belonging to the game
    def self.genres_of_game_by_id(id)
        @db.results_as_hash = false
        @db.execute('SELECT genre_id FROM game_genres WHERE game_id = ?', id).map{|x| x[0]}
    end

    # fetches the name of a genre in the database based on that genres id
    #
    # @option id [String] the id of a genre in the database
    #
    # @return [String] the name of the genre
    def self.genre_name_by_id(id)
        @db.execute('SELECT name FROM genres WHERE id = ?', id)[0][0]
    end

    # fetches all comments on a specific game based on that game's id
    #
    # @option id [String] the id of a game in the database
    #
    # @return [Array] containing all the comment hashes for that game
    def self.comments_by_game_id(id)
        @db.results_as_hash = true
        @db.execute('SELECT comments.id, comments.content FROM comment_user_game
                    INNER JOIN comments ON comment_user_game.comment_id = comments.id
                    WHERE game_id = ?', id)
    end

    # fetches a username based on the id of a comment belonging to them
    #
    # @option id [String] the id of a comment in the database
    #
    # @return [String] the username
    def self.username_by_comment_id(id)
        @db.results_as_hash = false
        user_id = @db.execute('SELECT user_id FROM comment_user_game WHERE comment_id=?', id)
        if user_id == []
            return []
        else 
            user_id = user_id[0][0]
        end
        @db.execute('SELECT username FROM users WHERE id=?', user_id)[0][0]
    end

    # adds a comment to the database (both in the comments table and the comment_user_game table)
    #
    # @option content [String] the content of the comment
    # @option user_id [String] the user_id of the user who wrote the comment
    # @option game_id [String] the game that the comment is on
    def self.add_comment(content, user_id, game_id)        
        @db.execute('INSERT INTO comments (content) VALUES (?)', content)
        @db.results_as_hash = false
        comment_id = @db.execute('SELECT MAX(id) FROM comments')[0][0]
        @db.execute('INSERT INTO comment_user_game (comment_id, user_id, game_id) VALUES (?,?,?)', comment_id, user_id, game_id)
    end

    # deletes a comment from the database (both from the comments table and the comment_user_game table)
    #
    # @option id [String] the id of the comment
    def self.delete_comment(id)
        @db.execute('DELETE FROM comments WHERE id=?', id)
        @db.execute('DELETE FROM comment_user_game WHERE comment_id=?', id)
    end

    # deletes a game from the database (both from the games table and the game_genres table)
    #
    # @option game_id [String] the id of the game
    # @see Model#game_genres_delete_all_by_game_id
    def self.delete_game(id)
        @db.execute('DELETE FROM games WHERE id=?', id)
        game_genres_delete_all_by_game_id(id)
    end

    # updates a game's parameters in the database
    #
    # @option title [String] the new title of the game
    # @option release_year [String] the new release year of the game
    # @option console_id [String] the new id of the console the game is for
    # @option part_of_series [String] "Yes" or "No" if the game is part of a series of other games
    # @option id [String] the new id of the game
    def self.update_game(title, release_year, console_id, part_of_series, id)
        @db.execute('UPDATE games SET title=?, release_year=?, console_id=?, part_of_series=? WHERE id=?', title, release_year, console_id, part_of_series, id)
    end

    # deletes all genres of a specific game based on that game's id
    #
    # @option id [String] the id of the game
    def self.game_genres_delete_all_by_game_id(id)
        @db.execute('DELETE FROM game_genres WHERE game_id=?', id)
    end

    # inserts a new entry into the game_genres table, letting us know which game has what genres
    #
    # @option game_id [String] the id of the game
    # @option genre_id [String] the id of the genre
    def self.game_genres_insert_new(game_id, genre_id)
        @db.execute('INSERT INTO game_genres (game_id, genre_id) VALUES (?,?)', game_id, genre_id)
    end

    # Creates a new id for a game. Works like the autoincrement keyword in sqlite,
    # but this way we don't have to depend on that. According to sqlite themselves, 
    # the autoincrement keyword "should be avoided if not strictly needed" (https://www.sqlite.org/autoinc.html)
    #
    # @option title [String] the new title of the game
    def self.create_id_for_new_game
        @db.execute('SELECT MAX(id) FROM games')[0][0] + 1
    end

    # inserts a new entry into the game_genres table, letting us know which game has what genres.
    #
    # @option game_id [String] the id of the game
    # @option genre_id [String] the id of the genre
    def self.add_game_genres(id, genre)
        @db.execute('INSERT INTO game_genres (game_id, genre_id) VALUES (?,?)', id, genre)
    end

    # inserts a new game into the database
    #
    # @option id [String] the id of the new game
    # @option title [String] the title of the new game
    # @option release_year [String] the release year of the new game
    # @option console_id [String] the id of the console the new game is for
    # @option part_of_series [String] "Yes" or "No" if the game is part of a series of other games
    def self.insert_into_new_game(id, title, release_year, console_id, part_of_series)
        @db.execute('INSERT INTO games (id, title, release_year, console_id, part_of_series) VALUES (?,?,?,?,?)', id, title, release_year, console_id, part_of_series)
    end

    # fetches the username of a user based on that user's id
    #
    # @option id [String] the id of the user
    # @return [String] the username of the user
    def self.username_by_user_id(id)
        @db.execute('SELECT username FROM users WHERE id = ?', id)[0][0]
    end

    # fetches the id of a user based on that user's username
    #
    # @option username [String] the username of the user
    # @return [String] the id of the user
    def self.user_id_by_username(username)
        @db.execute('SELECT id FROM users WHERE username = ?', username)[0][0]
    end

    # checks if a username already exists in the database
    #
    # @option username [String] a username
    # @return [Boolean]
    def self.username_is_unique?(username)
        @db.results_as_hash = true
        @db.execute('SELECT * from users WHERE username=?', username) == []
    end

    # checks if a user is an admin based on that user's username
    #
    # @option username [String] a username
    # @return [Boolean]
    def self.username_is_admin?(username)
        @db.execute('SELECT is_admin from users WHERE username=?', username)[0][0] == "Yes"
    end

    # inserts a new account into the database
    #
    # @option username [String] a username
    # @option pwdigest [String] the encrypted password of that user
    def self.create_account(username, pwdigest)
        id = @db.execute('SELECT MAX(id) FROM users')[0][0] + 1
        @db.execute('INSERT INTO users (id, username, pwdigest, is_admin) VALUES (?, ?, ?, ?)', id, username, pwdigest, "No")
    end

    # fetches the encrypted password from a user based on that user's username
    #
    # @option username [String] a username
    # @return [String] the encrypted password of that user
    def self.pwdigest_by_username(username)
        @db.execute('SELECT pwdigest from users WHERE username=?', username)[0][0]
    end
end