# Phase 1 Analytics Controller Implementation - Complete Documentation

**Date:** January 25, 2025  
**Scope:** Complete analytics controller redesign with Hero KPIs, Time-Based Performance, Traffic Analysis, and Medical Services tracking  
**File Modified:** `/app/controllers/admin_controller.rb` (analytics action)  
**Status:** ✅ COMPLETED - Controller logic implementation done

---

## Summary

Completely rewrote the `analytics` action in `AdminController` to provide comprehensive business intelligence for the medical clinic. The redesign includes period comparisons, % change calculations, real-time tracking, and detailed breakdowns across all key dimensions.

---

## 🎯 Phase 1 Components Implemented

### 1. **Hero KPI Dashboard** ✅

**Purpose:** Executive-level overview with period-over-period comparisons

**Metrics Calculated:**
- **Total Visits**: Current period visits + comparison with previous period
  - `@total_visits`, `@previous_total_visits`
  - `@total_visits_change` (absolute), `@total_visits_change_pct` (percentage)

- **Unique Visitors**: Distinct visitor tracking with comparisons
  - `@unique_visitors`, `@previous_unique_visitors`
  - `@unique_visitors_change`, `@unique_visitors_change_pct`

- **Pages per Visit**: Engagement depth metric
  - `@pages_per_visit`, `@previous_pages_per_visit`
  - `@pages_per_visit_change_pct`
  - Formula: `total_events / total_visits`

- **Bounce Rate**: Single-page visit percentage
  - `@bounce_rate`, `@previous_bounce_rate`
  - `@bounce_rate_change_pct`
  - Formula: `(single_page_visits / total_visits) * 100`

- **Average Session Duration**: Estimated time on site
  - `@avg_session_duration`, `@previous_avg_session_duration`
  - `@avg_session_duration_change_pct`
  - Formula: `pages_per_visit * 2.5 minutes`

- **Real-time Visitors**: Live user tracking
  - `@realtime_visitors` (visitors in last 5 minutes)

- **New vs Returning Visitors**: Audience composition
  - `@new_visitors`, `@returning_visitors`
  - `@previous_new_visitors`, `@previous_returning_visitors`

**Key Innovation:** Automatic comparison period calculation
```ruby
period_duration = @end_date - @start_date
@previous_period_start = @start_date - period_duration
@previous_period_end = @start_date - 1.second
```

---

### 2. **Time-Based Performance** ✅

**Purpose:** Temporal patterns and trends analysis

**Metrics Calculated:**
- **Hourly Distribution**: 24-hour breakdown
  - `@hourly_visits` (array of {hour, count})
  - Shows peak traffic hours

- **Daily Visits**: Trend over selected period
  - `@daily_visits` (array of {date, count})
  - Limited to 90 days max for performance

- **Day of Week Performance**: Weekly patterns
  - `@visits_by_day_of_week` (Sunday through Saturday)
  - Romanian day names: Duminică, Luni, Marți, Miercuri, Joi, Vineri, Sâmbătă

- **Hour of Day Heatmap**: 7 days × 24 hours matrix
  - `@heatmap_data` (last 7 days with hourly counts)
  - Format: `[{date: 'Mon 20', hours: [0, 3, 5, ...]}]`

- **Today/Week/Month Performance**:
  - `@visits_today`, `@unique_visitors_today`
  - `@visits_this_week`, `@unique_visitors_this_week`
  - `@visits_this_month`, `@unique_visitors_this_month`

- **Weekly Growth**: Week-over-week comparison
  - `@weekly_growth` (percentage change)

---

### 3. **Traffic Source Analysis** ✅

**Purpose:** Understand visitor acquisition channels

**Metrics Calculated:**
- **Basic Traffic Sources** (grouped):
  - Direct traffic (no referrer)
  - Google
  - Facebook
  - Instagram
  - LinkedIn (NEW)
  - "Alte surse" (other sources)
  - Stored in `@traffic_by_source` hash

- **Top Referrers** (LIMIT 20):
  - `@top_referrers_with_percentage`
  - Format: `{domain => {count: X, percentage: Y}}`

- **UTM Campaign Tracking** (NEW):
  - `@utm_sources` (top 10 UTM sources)
  - `@utm_mediums` (top 10 UTM mediums)
  - `@utm_campaigns` (top 10 UTM campaigns)
  - Enables marketing campaign ROI tracking

- **Browser, OS, Device Distribution**:
  - `@browsers` (top 8)
  - `@operating_systems` (top 8)
  - `@device_types` (all types)

---

### 4. **Medical Services Analytics** ✅

**Purpose:** Track service page performance and demand

**Metrics Calculated:**
- **Service Page Views**:
  - `@service_page_views` (total views on /servicii-medicale/*)
  - `@service_unique_visitors` (distinct visitors)

- **Top Viewed Service Pages** (LIMIT 15):
  - `@top_service_pages` (normalized URLs with counts)

- **Services with/without Members**:
  - `@services_with_members` (has attached doctor)
  - `@services_without_members` (standalone)

---

### 5. **Doctor Profile Analytics** ✅

**Purpose:** Track medical staff profile engagement

**Metrics Calculated:**
- **Member Profile Views**:
  - `@member_page_views` (total views on /echipa/*)
  - `@member_unique_visitors` (distinct visitors)

- **Top Viewed Member Profiles** (LIMIT 15):
  - `@top_member_pages` (normalized URLs with counts)

- **Content Completeness**:
  - `@members_with_bio` / `@members_without_bio`
  - `@members_with_photo` / `@members_without_photo`

---

### 6. **Geographic Intelligence** ✅

**Purpose:** Geographic distribution analysis

**Metrics Calculated:**
- **Countries** (LIMIT 15): `@visitors_by_country`
- **Romania - Counties** (LIMIT 20): `@visitors_by_county`
- **Romania - Cities** (LIMIT 20): `@visitors_by_city_romania`

---

### 7. **Page Performance** ✅

**Purpose:** Content effectiveness tracking

**Metrics Calculated:**
- **Most Viewed Pages** (LIMIT 20): `@most_viewed_pages`
- **Entry Pages** (LIMIT 15): `@top_entry_pages`
- **Exit Pages** (LIMIT 15): `@top_exit_pages`

---

### 8. **Engagement & Interaction** ✅

**Purpose:** User interaction tracking

**Metrics Calculated:**
- **Click Analytics**:
  - `@total_clicks` (all click events)
  - `@top_click_destinations` (top 10 clicked links)
  - `@top_clicked_elements` (top 10 by text)
  - `@clicks_by_page` (clicks grouped by page)
  - `@clicks_by_type` (element type distribution)

---

### 9. **Content Statistics** ✅

**Purpose:** Database content health metrics

**Metrics Calculated:**
- **Basic Counts**:
  - `@total_members`, `@total_services`, `@total_specialties`
  - `@total_professions`, `@total_facts`, `@total_users`

- **User Roles**:
  - `@admin_users`, `@god_mode_users`

- **Coverage Metrics**:
  - `@specialties_with_members` / `@specialties_without_members`
  - `@professions_with_members` / `@professions_without_members`
  - `@specialties_with_services` / `@specialties_without_services`
  - `@services_without_description`
  - `@members_without_specialty`

---

### 10. **Recent Activity** ✅

**Purpose:** Track content creation and updates

**Metrics Calculated:**
- **Time-based Creation**:
  - `@members_created_this_month`
  - `@services_created_this_month`
  - `@facts_updated_this_week`
  - `@users_created_this_month`

- **Recent Updates** (LIMIT 5 each):
  - `@recent_members`, `@recent_services`
  - `@recent_facts`, `@recent_users`

- **Most Updated** (LIMIT 10):
  - `@most_updated_members`, `@most_updated_services`

---

### 11. **Growth Trends** ✅

**Purpose:** 6-month historical growth analysis

**Metrics Calculated:**
- **Member Growth**: `@members_growth` (6 months of creation data)
- **Service Growth**: `@services_growth` (6 months of creation data)
- **Top Specialties**: `@top_specialties` (by service count, LIMIT 10)
- **Top Professions**: `@top_professions` (by member count, LIMIT 10)
- **Total Records**: `@total_records` (database size metric)

---

## 🛠️ Helper Methods

### `calculate_percentage_change(current, previous)` (NEW)
**Purpose:** Consistent % change calculation across all metrics

**Logic:**
```ruby
return 0 if previous.nil? || previous.zero?
(((current.to_f - previous.to_f) / previous.to_f) * 100).round(1)
```

**Usage:**
```ruby
@total_visits_change_pct = calculate_percentage_change(@total_visits, @previous_total_visits)
# Returns: +15.3% or -8.2%
```

### `normalize_url(url)` (existing)
Cleans URLs for display by removing domain, handling empty cases

### `calculate_start_date(period)` (existing)
Converts period parameter ('7', '30', '90', '180', '365', 'all', 'custom') to start date

---

## 🎨 Code Structure

### Organization Pattern
```ruby
# ===== SECTION NAME =====
# Clear section headers for all 11 major sections
# Grouped queries by purpose
# Reusable base queries (public_visits, previous_visits, events)
```

### Query Optimization Strategy
1. **Base Query Reuse**: `public_visits` and `events` defined once, reused throughout
2. **LIMIT Clauses**: All unbounded queries have sensible limits (10-20 items)
3. **Selected Columns**: Recent activity queries use `.select(:id, :name, :updated_at)` for performance
4. **Grouped Calculations**: Single GROUP BY queries instead of multiple count queries
5. **Eager Loading**: `.includes()` and `.joins()` to prevent N+1 queries

### Performance Targets
- **Query Count**: ~60-80 queries (up from 40-50, but still optimized)
- **Memory Usage**: Target <450M (was 690M before fixes)
- **Load Time**: Target <3 seconds (was 14+ seconds)

---

## 📊 Data Available for View

### Instance Variables Created (70+ variables)

**Hero KPIs:**
- `@total_visits`, `@previous_total_visits`, `@total_visits_change`, `@total_visits_change_pct`
- `@unique_visitors`, `@previous_unique_visitors`, `@unique_visitors_change`, `@unique_visitors_change_pct`
- `@pages_per_visit`, `@previous_pages_per_visit`, `@pages_per_visit_change_pct`
- `@bounce_rate`, `@previous_bounce_rate`, `@bounce_rate_change_pct`
- `@avg_session_duration`, `@previous_avg_session_duration`, `@avg_session_duration_change_pct`
- `@realtime_visitors`
- `@new_visitors`, `@returning_visitors`, `@previous_new_visitors`, `@previous_returning_visitors`

**Time-Based:**
- `@hourly_visits` (24-hour array)
- `@daily_visits` (up to 90 days array)
- `@visits_by_day_of_week` (7 days array)
- `@heatmap_data` (7 days × 24 hours)
- `@visits_today`, `@unique_visitors_today`
- `@visits_this_week`, `@unique_visitors_this_week`
- `@visits_this_month`, `@unique_visitors_this_month`
- `@weekly_growth`

**Traffic Sources:**
- `@traffic_by_source` (hash with Direct, Google, Facebook, Instagram, LinkedIn, Alte surse)
- `@top_referrers_with_percentage` (hash with {count, percentage})
- `@utm_sources`, `@utm_mediums`, `@utm_campaigns`
- `@browsers`, `@operating_systems`, `@device_types`

**Medical Services:**
- `@service_page_views`, `@service_unique_visitors`
- `@top_service_pages`
- `@services_with_members`, `@services_without_members`

**Doctor Profiles:**
- `@member_page_views`, `@member_unique_visitors`
- `@top_member_pages`
- `@members_with_bio`, `@members_without_bio`
- `@members_with_photo`, `@members_without_photo`

**Geographic:**
- `@visitors_by_country`, `@visitors_by_county`, `@visitors_by_city_romania`

**Pages:**
- `@most_viewed_pages`, `@top_entry_pages`, `@top_exit_pages`

**Engagement:**
- `@total_clicks`, `@top_click_destinations`, `@top_clicked_elements`
- `@clicks_by_page`, `@clicks_by_type`

**Content Stats:**
- `@total_members`, `@total_services`, `@total_specialties`, `@total_professions`, `@total_facts`, `@total_users`
- `@admin_users`, `@god_mode_users`
- `@services_per_specialty`, `@members_per_profession`, `@members_per_specialty`
- `@services_without_description`, `@members_without_specialty`
- `@specialties_with_members`, `@specialties_without_members`
- `@professions_with_members`, `@professions_without_members`
- `@specialties_with_services`, `@specialties_without_services`

**Activity:**
- `@members_created_this_month`, `@services_created_this_month`
- `@facts_updated_this_week`, `@users_created_this_month`
- `@recent_members`, `@recent_services`, `@recent_facts`, `@recent_users`
- `@most_updated_members`, `@most_updated_services`

**Growth:**
- `@members_growth`, `@services_growth`
- `@top_specialties`, `@top_professions`
- `@total_records`

---

## 🔄 Comparison Period Logic

**How It Works:**
1. Calculate current period duration: `period_duration = @end_date - @start_date`
2. Set comparison period:
   ```ruby
   @previous_period_start = @start_date - period_duration
   @previous_period_end = @start_date - 1.second
   ```
3. Example: If period is Jan 11-25 (15 days):
   - Current: Jan 11 00:00 to Jan 25 23:59
   - Previous: Dec 27 00:00 to Jan 10 23:59

**Benefits:**
- **Apples-to-apples comparison**: Same duration for fair comparison
- **Automatic calculation**: Works for any period (7, 30, 90 days, custom)
- **Consistent methodology**: All % changes use same helper method

---

## 🚀 Next Steps (View Implementation)

### Task #6: Build New Analytics View Structure

**Required Sections:**
1. **Hero KPI Cards** (6 large metric cards with sparklines)
2. **Real-time Pulse** (live visitors, active pages)
3. **Time-Based Performance** (charts + heatmap)
4. **Traffic Sources** (pie charts + tables)
5. **Medical Services** (service performance cards)
6. **Doctor Profiles** (profile engagement metrics)
7. **Geographic Intelligence** (3-level breakdown)
8. **Page Performance** (top pages with metrics)
9. **Engagement** (click analytics)
10. **Content Health** (database metrics)
11. **Growth Trends** (6-month charts)

**Design Principles:**
- Data-dense layout (3-4 column responsive grid)
- Chart-heavy (Chart.js + sparklines)
- Collapsible/expandable sections
- Period comparison toggle
- Performance indicators (green/yellow/red for bounce rate, etc.)

---

## 📝 Testing Checklist

Before deployment, verify:

- [ ] Analytics page loads without errors
- [ ] All 70+ instance variables populated correctly
- [ ] Query count < 80 queries
- [ ] Memory usage < 450M
- [ ] Load time < 3 seconds
- [ ] Period filter works (7, 30, 90, 180, 365, all, custom)
- [ ] Custom date range works
- [ ] All % changes calculate correctly
- [ ] Real-time visitors updates
- [ ] UTM tracking displays correctly
- [ ] Heatmap data structure correct
- [ ] No N+1 query issues
- [ ] PostgreSQL compatibility (GROUP BY compliance)

---

## 🔗 Related Files

- **Backup:** `admin_controller.rb.backup_20260125`
- **View:** `app/views/admin/analytics.html.erb` (to be redesigned)
- **Routes:** `config/routes.rb` → `/dashboard/analytics`
- **Policy:** `app/policies/application_policy.rb` (admin access required)

---

## 📚 Technical References

**Ahoy Gem:**
- `Ahoy::Visit` table: visit tracking with geolocation
- `Ahoy::Event` table: user interactions (page views, clicks)

**PostgreSQL:**
- `EXTRACT(HOUR FROM started_at)` for hourly grouping
- `DATE(started_at)` for daily grouping
- `DATE_TRUNC('month', created_at)` for monthly grouping
- `EXTRACT(DOW FROM started_at)` for day of week (0=Sunday)

**Ruby/Rails:**
- `.group()` for aggregations
- `.count`, `.distinct.count(:column)` for counting
- `.having('COUNT(*) = 1')` for filtering aggregates
- `.includes()`, `.joins()` for eager loading
- `.select(:id, :name)` for column selection

---

## ✅ Completion Status

**Phase 1 Controller Logic: COMPLETE**

All Hero KPI calculations, time-based metrics, traffic analysis, service analytics, doctor profile tracking, geographic intelligence, page performance, engagement metrics, content statistics, and growth trends are fully implemented and optimized.

**Next Task:** Redesign analytics.html.erb view to display all this rich data.

---

**Author:** GitHub Copilot (Claude Sonnet 4.5)  
**Date:** January 25, 2025  
**Project:** Spinal Care RoR - Analytics Dashboard Redesign Phase 1
