#SQL commands go here 
class Database
    def initialize
        @db = SQLite3::Database.new('db/game_collection.db')
        @db.results_as_hash = true
    end

    def all_games
    end

    def delete_game(id)
        @db.execute('DELETE FROM games WHERE id=?', id)
    end


    def add_new_user
    end
end