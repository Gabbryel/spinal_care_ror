# Pages about conditions (afecțiuni) and procedures (proceduri): written by
# the clinic in the dashboard, linked to specialties (whose doctors they
# show) and to medical services (whose prices they show).
class CreateHealthTopics < ActiveRecord::Migration[8.0]
  def change
    create_table :health_topics do |t|
      t.string :kind, null: false, default: "afectiune" # afectiune | procedura
      t.string :name, null: false
      t.string :slug, null: false
      t.text :summary
      t.string :seo_title
      t.string :meta_description
      # [{ "q" => "...", "a" => "..." }]
      t.jsonb :faqs, null: false, default: []
      t.boolean :published, null: false, default: false
      t.datetime :published_at
      t.timestamps
    end
    add_index :health_topics, [:kind, :slug], unique: true
    add_index :health_topics, :published

    create_table :health_topic_specialties do |t|
      t.references :health_topic, null: false, foreign_key: true
      t.references :specialty, null: false, foreign_key: true
      t.timestamps
    end
    add_index :health_topic_specialties, [:health_topic_id, :specialty_id], unique: true, name: "index_topic_specialties_unique"

    create_table :health_topic_services do |t|
      t.references :health_topic, null: false, foreign_key: true
      t.references :medical_service, null: false, foreign_key: true
      t.timestamps
    end
    add_index :health_topic_services, [:health_topic_id, :medical_service_id], unique: true, name: "index_topic_services_unique"
  end
end
