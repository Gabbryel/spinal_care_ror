class AddVisitIdNameIndexToAhoyEvents < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :ahoy_events, %i[visit_id name], algorithm: :concurrently
  end
end
