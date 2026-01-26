# Analytics Dashboard - Phase 3 Testing Guide

**Date**: January 26, 2026  
**Branch**: `analytics-january-25`  
**Prerequisites**: Phase 1 ✅ Phase 2 ✅

## Overview

Phase 3 focuses on comprehensive testing of the analytics dashboard with real (or seeded) data. This document provides step-by-step testing procedures, expected outcomes, and troubleshooting steps.

---

## Prerequisites

### 1. Complete Phase 2
Ensure Phase 2 commit is present:
```bash
git log --oneline | head -5
# Should show: d382170 Phase 2: Add empty states and data structure fixes
```

### 2. Database Ready
```bash
rails db:migrate
# Ensure ahoy_visits and ahoy_events tables exist
```

### 3. Server Running
```bash
bin/dev
# Should start web, js, and css processes
```

### 4. Generate Test Data (Optional but Recommended)
```bash
rails analytics:seed
# Generates 90 days of realistic analytics data
# Expected output: "✅ Seeding complete! 📊 Total visits: ~2700"
```

---

## Testing Checklist

### ✅ Authentication & Access (5 mins)

#### Test 1.1: Sign In
1. Navigate to `/users/sign_in`
2. Sign in with admin credentials
3. **Expected**: Redirected to dashboard home

#### Test 1.2: Authorization
1. Navigate to `/dashboard/analytics`
2. **Expected**: 
   - ✅ Admins: Page loads successfully
   - ❌ Non-admins: Redirected with "Nu sunteți autorizat" message
   - ❌ Guests: Redirected to sign-in page

#### Test 1.3: Pundit Policy
1. Sign in as non-admin user
2. Try accessing `/dashboard/analytics`
3. **Expected**: Pundit::NotAuthorizedError handled gracefully

---

### ✅ Hero KPIs Display (10 mins)

Navigate to `/dashboard/analytics?period=30` (default period)

#### Test 2.1: Total Visits
1. Check "Vizite Totale" card
2. **Expected**:
   - Displays numeric count (e.g., "1,234")
   - Shows trend icon (↑ or ↓)
   - Shows percentage change vs previous period
   - Trend color: green (↑) or red (↓)

#### Test 2.2: Unique Visitors
1. Check "Vizitatori Unici" card
2. **Expected**:
   - Displays unique visitor count
   - Shows trend percentage
   - Number ≤ Total Visits (since one visitor can have multiple visits)

#### Test 2.3: Avg Session Duration
1. Check "Durată Medie" card
2. **Expected**:
   - Displays time in format: "2m 34s" or "45s"
   - Shows trend
   - Reasonable value (typically 1-5 minutes for medical sites)

#### Test 2.4: Bounce Rate
1. Check "Rată Respingere" card
2. **Expected**:
   - Displays percentage (e.g., "45%")
   - Shows trend
   - Value between 0-100%
   - Lower is better (green ↓ is good)

#### Test 2.5: Top City
1. Check "Oraș Principal" card
2. **Expected**:
   - Displays city name (e.g., "București")
   - Shows visit count for that city
   - No "(null)" or blank values

#### Test 2.6: Top Referrer
1. Check "Sursă Principală" card
2. **Expected**:
   - Displays domain (e.g., "google.com", "Direct")
   - Shows visit count from that source
   - Handles null referrers gracefully

#### Test 2.7: Most Viewed Page
1. Check "Pagină Populară" card
2. **Expected**:
   - Displays page path (e.g., "/echipa/dr-ion-popescu")
   - Shows view count
   - Path is clickable (optional enhancement)

---

### ✅ Period Filters (15 mins)

Test ALL period filters to ensure data updates correctly.

#### Test 3.1: Quick Filters
Test each quick filter button:

**Today**:
```
Click "Azi" button
Expected:
- URL changes to ?period=today
- Hero KPIs update
- Daily chart reloads (may show 1 data point)
- Lower numbers than longer periods
```

**This Week**:
```
Click "Săptămâna" button
Expected:
- URL: ?period=week
- 7 days of data
- Chart shows 7 points
```

**This Month**:
```
Click "Luna" button
Expected:
- URL: ?period=month
- ~30 days of data
- Chart shows current month trend
```

**Last 7 Days**:
```
Click "7 zile" button
Expected:
- URL: ?period=7
- Exactly 7 days of data
```

**Last 30 Days**:
```
Click "30 zile" button (DEFAULT)
Expected:
- URL: ?period=30
- Exactly 30 days of data
- This is the default period on page load
```

**Last 90 Days**:
```
Click "90 zile" button
Expected:
- URL: ?period=90
- 3 months of data
- Chart may look compressed
```

#### Test 3.2: Custom Date Range
1. Click "Personalizat" to show date inputs
2. Enter start date: `2025-12-01`
3. Enter end date: `2025-12-31`
4. Click "Aplică"
5. **Expected**:
   - URL: `?period=custom&custom_start_date=2025-12-01&custom_end_date=2025-12-31`
   - Only December 2025 data shown
   - Chart shows 31 data points

#### Test 3.3: Edge Cases - Invalid Dates
1. Select custom date range
2. Set end date before start date
3. **Expected**:
   - Frontend validation prevents submission OR
   - Backend returns friendly error message

#### Test 3.4: Edge Cases - Future Dates
1. Select custom date range with future end date
2. **Expected**:
   - Shows data up to current date
   - No future predictions

---

### ✅ Daily Traffic Chart (Lazy Load) (10 mins)

#### Test 4.1: Lazy Loading
1. Load `/dashboard/analytics`
2. Open browser DevTools → Network tab
3. Scroll to "Evoluție Trafic" section
4. **Expected**:
   - Chart section initially shows loading state
   - Network request to `/dashboard/analytics/daily_chart?period=30`
   - Chart loads only when scrolled into view (Intersection Observer)

#### Test 4.2: Chart Rendering
1. Wait for chart to load
2. **Expected**:
   - Line chart with blue line
   - X-axis shows dates ("01 Jan", "02 Jan", ...)
   - Y-axis shows visit counts
   - Smooth curve (tension: 0.4)
   - Gradient fill under line

#### Test 4.3: Chart Interactivity
1. Hover over data points
2. **Expected**:
   - Tooltip shows: "01 Ian: 150 vizite"
   - Hover effect on points

#### Test 4.4: Period Filter Integration
1. Change period filter (e.g., click "7 zile")
2. **Expected**:
   - Chart reloads with new period parameter
   - New request: `/dashboard/analytics/daily_chart?period=7`
   - Chart updates to show 7 days

#### Test 4.5: Empty State
1. Set custom date range with no data (e.g., future dates)
2. **Expected**:
   - Shows empty state: "Nu există date disponibile pentru perioada selectată."
   - No Chart.js errors in console
   - Emoji icon 📊 displayed

---

### ✅ Drill-Down Sections (Expandable) (20 mins)

#### Test 5.1: Geography Section
**Before Expand**:
1. Section shows "Geografie" with expand button
2. Content hidden

**After Expand**:
1. Click expand icon
2. **Expected**:
   - Network request: `/dashboard/analytics/geography?period=30`
   - Shows two tables: "Top Orașe" and "Top Țări"
   - Each city/country shows visit count
   - Progress bars proportional to counts
   - Data sorted descending by count

**Empty State**:
1. Test with no geo data (if Ahoy geocoding disabled)
2. **Expected**: "Nu există date geografice disponibile..."

#### Test 5.2: Traffic Sources Section
**Before Expand**:
- Section collapsed

**After Expand**:
1. Click expand
2. **Expected**:
   - Pie chart with traffic sources (Direct, Google, Facebook, etc.)
   - Legend shows percentages
   - Table below shows referrer details
   - Colors consistent between chart and table

**Empty State**:
- Should show emoji and message if no referrer data

#### Test 5.3: Top Pages Section
**Before Expand**:
- Collapsed

**After Expand**:
1. Click expand
2. **Expected**:
   - Two columns: "Pagini Cele Mai Vizualizate" and "Pagini de Intrare"
   - Each page shows:
     - Path (e.g., "/echipa/dr-ion-popescu")
     - View count
     - Progress bar
   - Sorted by view count descending

**Empty State**:
- Shows if no page view events tracked

#### Test 5.4: Content Performance Section
**Before Expand**:
- Collapsed

**After Expand**:
1. Click expand
2. **Expected**:
   - Three columns:
     - "Doctori Populari" (with profile photos)
     - "Specialități Populare"
     - "Servicii Populare"
   - Each item shows:
     - Name/title
     - View count
     - Progress bar
   - Links to actual content pages

**Empty State**:
- Shows if no doctor/specialty/service views

#### Test 5.5: User Journey Section
**Before Expand**:
- Collapsed

**After Expand**:
1. Click expand
2. **Expected**:
   - Click heatmap (if implemented)
   - Conversion funnel (if implemented)
   - Path analysis (if implemented)
   - OR: Coming soon message

**Empty State**:
- Shows if no click events tracked

---

### ✅ Auto-Refresh Feature (5 mins)

#### Test 6.1: Wait for Auto-Refresh
1. Load dashboard
2. Note current visit count
3. Wait 60 seconds
4. **Expected**:
   - Page automatically refreshes
   - URL preserved (period parameter kept)
   - No full page reload (Turbo refresh)
   - Updated data displayed

#### Test 6.2: Disable Auto-Refresh (Optional)
1. Check if there's a "Pause auto-refresh" button
2. **Expected**:
   - Can toggle auto-refresh on/off
   - Preference persisted (sessionStorage)

---

### ✅ Responsive Design (10 mins)

#### Test 7.1: Mobile (320px - 768px)
1. Open Chrome DevTools
2. Toggle device toolbar (Cmd+Shift+M)
3. Select "iPhone SE" (375px width)
4. **Expected**:
   - Hero KPI cards stack vertically
   - 1 card per row (full width)
   - Charts are scrollable horizontally if needed
   - Touch-friendly buttons (min 44px tap target)
   - Filters collapse to dropdown

#### Test 7.2: Tablet (768px - 1024px)
1. Select "iPad" (768px)
2. **Expected**:
   - Hero KPIs: 2 cards per row
   - Charts full width
   - Tables scrollable if wide

#### Test 7.3: Desktop (1024px+)
1. View on desktop resolution
2. **Expected**:
   - Hero KPIs: 3-4 cards per row
   - Charts full width with comfortable margins
   - No horizontal scroll

---

### ✅ Performance Testing (10 mins)

#### Test 8.1: Page Load Time
1. Open Chrome DevTools → Network tab
2. Refresh dashboard with "Disable cache" checked
3. **Expected**:
   - Initial HTML load: < 500ms
   - Hero KPIs visible: < 1s
   - Daily chart lazy loaded: < 2s total
   - No layout shift (CLS score)

#### Test 8.2: Database Query Efficiency
1. Check Rails logs: `tail -f log/development.log`
2. Refresh dashboard
3. **Expected**:
   - Each KPI query: < 100ms
   - Total queries per page load: < 20
   - No N+1 query warnings
   - Ahoy queries use indexes (check with EXPLAIN)

#### Test 8.3: Chart Rendering
1. Open browser Performance profiler
2. Record while expanding all sections
3. **Expected**:
   - Chart.js initialization: < 200ms per chart
   - No janky animations (60 FPS)
   - Memory usage reasonable (< 100MB)

---

### ✅ Error Handling (10 mins)

#### Test 9.1: Network Errors
1. Open DevTools → Network tab
2. Set throttling to "Offline"
3. Expand a section
4. **Expected**:
   - Friendly error message (Romanian)
   - Retry button
   - No JavaScript console errors

#### Test 9.2: Invalid Period Parameter
1. Manually navigate to: `/dashboard/analytics?period=invalid`
2. **Expected**:
   - Falls back to default period (30)
   - No 500 error

#### Test 9.3: Missing Ahoy Tables
1. (In development only) Drop Ahoy tables: `rails db:drop_table ahoy_visits ahoy_events`
2. Load dashboard
3. **Expected**:
   - Graceful error message
   - Instructions to run migrations

#### Test 9.4: Empty Database
1. Clear all Ahoy data: `rails analytics:clear` (enter "yes")
2. Load dashboard
3. **Expected**:
   - All sections show empty states
   - No errors in console
   - No 500 errors

---

### ✅ Browser Compatibility (10 mins)

Test on multiple browsers:

#### Test 10.1: Chrome/Chromium (Latest)
- ✅ All features work
- ✅ Chart.js renders correctly
- ✅ Turbo Frames load

#### Test 10.2: Firefox (Latest)
- ✅ Check Chart.js compatibility
- ✅ Intersection Observer for lazy load

#### Test 10.3: Safari (Latest)
- ✅ CSS Grid layout
- ✅ Date input polyfill (if needed)

#### Test 10.4: Mobile Safari (iOS)
- ✅ Touch interactions
- ✅ Viewport meta tag
- ✅ -webkit prefixes for CSS

---

## Expected Results Summary

### Success Criteria
- ✅ All Hero KPIs display correctly with trends
- ✅ Period filters update data in real-time
- ✅ Daily chart lazy loads and renders smoothly
- ✅ All 5 drill-down sections expand and load data
- ✅ Empty states show when no data available
- ✅ No JavaScript errors in console
- ✅ No 500 errors from backend
- ✅ Responsive on mobile/tablet/desktop
- ✅ Auto-refresh works every 60 seconds
- ✅ Page load under 2 seconds

### Performance Benchmarks
- Initial page load: < 1s (Hero KPIs)
- Lazy-loaded sections: < 500ms each
- Database queries: < 100ms per query
- Chart rendering: < 200ms per chart
- Memory usage: < 100MB

---

## Troubleshooting

### Issue: Empty States Showing When Data Exists

**Symptoms**:
- Dashboard shows "Nu există date disponibile..." but data exists in database

**Check**:
```bash
rails console
Ahoy::Visit.count  # Should be > 0
Ahoy::Event.count  # Should be > 0
```

**Fix**:
- Ensure visits have `started_at` in selected period
- Check `landing_page NOT LIKE '%/dashboard%'` filter (should exclude admin visits)

### Issue: Chart Not Rendering

**Symptoms**:
- Blank canvas where chart should be
- Console error: "Cannot read property 'getContext' of null"

**Check**:
- Inspect HTML: `<canvas id="dailyTrafficChart">` should exist
- Check conditional: `<% if @daily_data.sum > 0 %>`
- Verify Chart.js CDN loaded: Check Network tab for `chart.js`

**Fix**:
- Ensure `@daily_data` is an array, not nil
- Check browser console for specific error

### Issue: Lazy Loading Not Working

**Symptoms**:
- All sections load immediately (not lazy)
- Multiple network requests on page load

**Check**:
- Turbo Frames: `<turbo-frame id="daily-chart" loading="lazy">`
- Intersection Observer support: Check browser compatibility

**Fix**:
- Add polyfill for older browsers
- Verify Turbo is loaded: Check `<meta name="turbo-visit-control">`

### Issue: Period Filters Not Updating Data

**Symptoms**:
- Click period button, URL changes, but data stays same

**Check**:
- Inspect URL params: `?period=7` should be present
- Check controller: `params[:period]` should be used in queries

**Fix**:
- Verify form submission: `<form method="get">`
- Check Turbo Frame: `data-turbo-frame="_top"` to reload whole page

### Issue: 500 Error on Page Load

**Symptoms**:
- Rails error page or "Something went wrong"

**Check**:
```bash
tail -f log/development.log
# Look for ActiveRecord errors or NoMethodError
```

**Common Causes**:
- Missing Ahoy tables: `rails db:migrate`
- Nil variable in view: Check all instance variables set in controller
- Missing association: Doctor/Specialty/Service deleted but referenced

### Issue: Slow Query Performance

**Symptoms**:
- Page takes > 5 seconds to load
- Database queries timeout

**Check**:
```bash
# In Rails console
Ahoy::Visit.explain.where(started_at: 30.days.ago..Time.now).count
# Should show INDEX usage, not FULL TABLE SCAN
```

**Fix**:
- Add indexes to Ahoy tables:
  ```ruby
  add_index :ahoy_visits, :started_at
  add_index :ahoy_visits, :city
  add_index :ahoy_visits, :referring_domain
  ```

---

## Test Data Notes

### Seed Task Details

`rails analytics:seed` generates:
- **90 days** of historical data
- **~2,700 visits** total (30 visits/day avg, decreasing with age)
- **~7,500 page views** (2-5 per visit)
- **~540 click events** (20% of visits)

Cities: București, Cluj-Napoca, Timișoara, Iași, Constanța, Craiova, Brașov, Galați, Ploiești, Oradea  
Countries: România, Moldova, Italia, Spania, Germania, Franța  
Referrers: Direct, Google, Facebook, Instagram  

### Clearing Test Data

```bash
rails analytics:clear
# Type "yes" to confirm
```

---

## Next Steps After Testing

1. **Document Issues**: Note any bugs in GitHub issues
2. **Phase 3 Complete Document**: Create `ANALYTICS_PHASE3_COMPLETE.md`
3. **Merge to Main**: If all tests pass, merge `analytics-january-25` → `main`
4. **Deploy to Staging**: Test on staging environment with real data
5. **Optional Phase 4**: Enhancements (Stimulus controllers, export, advanced features)

---

## Sign-Off Checklist

Before marking Phase 3 complete, confirm:

- [ ] All test sections above completed
- [ ] Zero JavaScript errors in console
- [ ] All empty states display correctly
- [ ] Charts render on all tested browsers
- [ ] Mobile responsive confirmed
- [ ] Performance benchmarks met
- [ ] No 500 errors during testing
- [ ] Documentation updated
- [ ] Ready for production deployment

---

**Testing Duration Estimate**: 2-3 hours total  
**Prerequisites**: Completed Phase 1 & Phase 2  
**Next Phase**: Phase 4 (Optional Enhancements) or Production Deployment
