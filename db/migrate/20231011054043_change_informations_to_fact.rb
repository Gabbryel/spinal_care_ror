class ChangeInformationsToFact < ActiveRecord::Migration[7.0]
  def change
    rename_table :information, :facts
  end
end
