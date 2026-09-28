validates :email, uniqueness: { case_sensitive: false }
add_index :users, :email, unique: true
