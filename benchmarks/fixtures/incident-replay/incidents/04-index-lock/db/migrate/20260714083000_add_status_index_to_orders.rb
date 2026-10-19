class AddStatusIndexToOrders < ActiveRecord::Migration[7.1]
  def change
    add_index :orders, :status
  end
end
