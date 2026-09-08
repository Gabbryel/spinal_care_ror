class AddStartedAtIndexToAhoyVisits < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :ahoy_visits, :started_at, algorithm: :concurrently
  end
end
