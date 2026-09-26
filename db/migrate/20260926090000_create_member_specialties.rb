class CreateMemberSpecialties < ActiveRecord::Migration[8.0]
  # A member can practise more than one specialty. members.specialty_id stays
  # as the primary one (card link, meta description); this table holds all of
  # them, the primary included.
  def up
    create_table :member_specialties do |t|
      t.references :member, null: false, foreign_key: true
      t.references :specialty, null: false, foreign_key: true
      t.timestamps
    end
    add_index :member_specialties, %i[member_id specialty_id], unique: true

    execute <<~SQL
      INSERT INTO member_specialties (member_id, specialty_id, created_at, updated_at)
      SELECT members.id, members.specialty_id, NOW(), NOW()
      FROM members
      JOIN specialties ON specialties.id = members.specialty_id
    SQL
  end

  def down
    drop_table :member_specialties
  end
end
