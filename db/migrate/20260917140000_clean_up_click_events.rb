# Data-only migration for the Ahoy "$click" events recorded since January 2026.
#
# The click tracker re-bound its listener on every Turbo visit (up to eight
# copies of one click), stored every button press (cookie banner, modal
# close...) with destination "internal-action", and did not classify clicks.
# This unifies the legacy "click" name, drops the duplicates, backfills a
# `category` property (kept in sync with click_tracker_controller.js) and
# deletes the button presses that have no destination and are not the booking
# button.
class CleanUpClickEvents < ActiveRecord::Migration[8.0]
  def up
    execute "UPDATE ahoy_events SET name = '$click' WHERE name = 'click'"

    execute <<~SQL
      DELETE FROM ahoy_events a
      USING ahoy_events b
      WHERE a.name = '$click' AND b.name = '$click'
        AND a.visit_id = b.visit_id
        AND a.properties->>'timestamp' = b.properties->>'timestamp'
        AND a.id > b.id
    SQL

    execute <<~SQL
      UPDATE ahoy_events
      SET properties = properties || jsonb_build_object('category',
        CASE
          WHEN properties->>'destination' ILIKE 'tel:%' THEN 'call'
          WHEN properties->>'destination' ILIKE 'mailto:%' THEN 'email'
          WHEN properties->>'destination' ~* 'wa\\.me|whatsapp' THEN 'whatsapp'
          WHEN properties->>'destination' ~* 'facebook\\.com|instagram\\.com|tiktok\\.com|youtube\\.com|linkedin\\.com' THEN 'social'
          WHEN properties->>'destination' ~* 'maps\\.google|google\\.[a-z.]+/maps|goo\\.gl/maps|maps\\.app\\.goo\\.gl|waze\\.com' THEN 'map'
          WHEN properties->>'destination' ~* 'programari\\.spinalcare\\.ro' THEN 'booking'
          WHEN properties->>'destination' = 'internal-action'
               AND (properties->>'classes' ~ 'cta-button|side-nav-cta|member-book-btn'
                    OR properties->>'text' ~* 'program') THEN 'booking'
          WHEN properties->>'destination' = 'internal-action' THEN NULL
          WHEN properties->>'destination' ~* '^https?://(www\\.)?(spinalcare\\.ro|localhost|[a-z0-9.-]*lvh\\.me)(:[0-9]+)?(/|$)' THEN 'nav'
          WHEN properties->>'destination' ~* '^https?://' THEN 'external'
          ELSE NULL
        END)
      WHERE name = '$click' AND properties->>'category' IS NULL
    SQL

    execute <<~SQL
      UPDATE ahoy_events
      SET properties = properties || '{"destination": "programari.spinalcare.ro (modal)"}'
      WHERE name = '$click' AND properties->>'category' = 'booking'
        AND properties->>'destination' = 'internal-action'
    SQL

    execute "DELETE FROM ahoy_events WHERE name = '$click' AND properties->>'category' IS NULL"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
