class AddReplacementAndPilotTracking < ActiveRecord::Migration[8.1]
  def change
    add_reference :players, :replaces, foreign_key: { to_table: :players }, index: { unique: true }
    add_reference :race_results, :pilot, foreign_key: { to_table: :players }
  end
end
