class CreateMedicinesConsumptions < ActiveRecord::Migration[8.0]
  def change
    create_table :medicines_consumptions do |t|
      t.string :month, null: false
      t.integer :year, null: false
      t.decimal :consumption, precision: 10, scale: 2, null: false, default: 0.0

      t.timestamps
    end
    
    add_index :medicines_consumptions, [:year, :month], unique: true
    add_index :medicines_consumptions, :year
  end
end
