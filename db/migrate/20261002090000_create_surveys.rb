# Patient satisfaction questionnaires: surveys, their questions, and the
# anonymous responses submitted from the site.
class CreateSurveys < ActiveRecord::Migration[8.0]
  def change
    create_table :surveys do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :intro
      t.text :thank_you
      t.boolean :active, null: false, default: false
      # Comma-separated addresses alerted about negative responses.
      t.string :alert_emails
      t.timestamps
    end
    add_index :surveys, :slug, unique: true

    create_table :survey_questions do |t|
      t.references :survey, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :section
      t.text :text, null: false
      # rating | choice | text
      t.string :kind, null: false, default: "rating"
      # [{ "label" => "Foarte bine", "score" => 100 }, ...]; score nil = not evaluative
      t.jsonb :options, null: false, default: []
      t.boolean :required, null: false, default: false
      # Answers to a segment question (specialty, age, sex) split the interpretation.
      t.boolean :segment, null: false, default: false
      # The overall-impression question: its answer is the satisfaction headline.
      t.boolean :headline, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :survey_questions, [:survey_id, :position]

    create_table :survey_responses do |t|
      t.references :survey, null: false, foreign_key: true
      # { "<question id>" => { "label" => "...", "score" => 100 } } or { "text" => "..." }
      t.jsonb :answers, null: false, default: {}
      t.float :score
      t.boolean :alert, null: false, default: false
      t.jsonb :alert_reasons, null: false, default: []
      t.string :status, null: false, default: "new"
      t.text :staff_note
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.string :source
      t.timestamps
    end
    add_index :survey_responses, [:survey_id, :created_at]
    add_index :survey_responses, :alert
  end
end
