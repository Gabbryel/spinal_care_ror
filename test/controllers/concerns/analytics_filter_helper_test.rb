require "test_helper"

class AnalyticsFilterHelperTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Host
    include AnalyticsFilterHelper
    public :bot_visit?, :filter_bot_visits
  end

  REAL_BROWSERS = [
    "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Mobile Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.6 Mobile/15E148 Safari/604.1",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0"
  ].freeze

  BOTS = [
    "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
    "Mozilla/5.0 (compatible; AhrefsBot/7.0; +http://ahrefs.com/robot/)",
    "rogerbot/1.2 (https://moz.com/help/guides/moz-procedures/what-is-rogerbot)",
    "curl/8.4.0",
    "python-requests/2.31"
  ].freeze

  test "real browsers are not classified as bots" do
    REAL_BROWSERS.each { |ua| refute Host.new.bot_visit?(ua), ua }
  end

  test "known crawlers are classified as bots" do
    BOTS.each { |ua| assert Host.new.bot_visit?(ua), ua }
  end

  test "the SQL filter keeps browser visits and drops crawler visits" do
    keep = Ahoy::Visit.create!(visit_token: SecureRandom.uuid, visitor_token: SecureRandom.uuid, user_agent: REAL_BROWSERS.first, started_at: Time.current)
    drop = Ahoy::Visit.create!(visit_token: SecureRandom.uuid, visitor_token: SecureRandom.uuid, user_agent: BOTS.first, started_at: Time.current)
    kept = Host.new.filter_bot_visits(Ahoy::Visit.where(id: [keep.id, drop.id])).pluck(:id)
    assert_equal [keep.id], kept
  end
end
