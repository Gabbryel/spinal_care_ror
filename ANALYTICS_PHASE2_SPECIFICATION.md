# Phase 2 Analytics Specification

## Overview

Phase 2 will extend the analytics dashboard with advanced behavioral analytics, patient journey tracking, medicine consumption insights, and conversion funnels.

---

## 🎯 Phase 2 Components

### 1. Patient Journey Analytics
**Goal:** Understand how visitors navigate through the website

**Metrics to Implement:**
- **Visit Paths Analysis**
  - Most common navigation sequences (e.g., Homepage → Services → Doctor Profile)
  - Average path length (pages per journey)
  - Entry point → Conversion point flows
  
- **Drop-off Analysis**
  - Pages with highest exit rates
  - Bottlenecks in patient journey
  - Forms abandoned without submission
  
- **Returning Visitor Behavior**
  - Time between visits
  - Pages revisited most often
  - Loyalty metrics (1st visit, 2nd visit, 3+ visits)

**Controller Implementation:**
```ruby
# Visit Paths (Ahoy::Event sequences)
@common_paths = events.group(:visit_id)
                      .order('COUNT(*) DESC')
                      .limit(10)
                      .pluck(:visit_id)
                      .map do |visit_id|
  events.where(visit_id: visit_id)
        .order(:time)
        .pluck("properties->>'url'")
        .map { |url| normalize_url(url) }
end

# Drop-off Pages
@high_exit_pages = # Pages with high bounce rates

# Returning Visitor Timeline
@visitor_timeline = public_visits.group(:visitor_token)
                                 .having('COUNT(*) > 1')
                                 .count
                                 .transform_values { |count| count }
```

**View Design:**
- Sankey diagram for common paths
- Funnel visualization for drop-offs
- Timeline chart for returning visitors

---

### 2. Medicine Consumption Analytics
**Goal:** Track medicine inventory trends and budget adherence

**Metrics to Implement:**
- **Monthly Consumption Trends**
  - Line chart: consumption over last 12 months
  - Category breakdown (antibiotics, pain management, etc.)
  - Top 10 most consumed medications
  
- **Budget vs Actual**
  - Comparison chart (budgeted vs actual spend)
  - Variance analysis (over/under budget)
  - Forecast for next quarter
  
- **Year-over-Year Comparison**
  - Same month comparison (Jan 2025 vs Jan 2024)
  - Growth/decline percentages
  - Seasonal patterns

**Controller Implementation:**
```ruby
# Monthly Trends (last 12 months)
@medicine_monthly = MedicinesConsumption.where('created_at >= ?', 12.months.ago)
                                        .group("DATE_TRUNC('month', created_at)")
                                        .sum(:total_amount)

# Budget Variance
@budget_variance = MedicinesConsumption.select('SUM(total_amount) as actual, SUM(budget) as budgeted')
                                       .where('created_at >= ?', 1.month.ago)
                                       .first

# YoY Comparison
current_year = MedicinesConsumption.where('EXTRACT(YEAR FROM created_at) = ?', Date.today.year).sum(:total_amount)
previous_year = MedicinesConsumption.where('EXTRACT(YEAR FROM created_at) = ?', Date.today.year - 1).sum(:total_amount)
@medicine_yoy_change = calculate_percentage_change(current_year, previous_year)
```

**View Design:**
- Line chart with dual axes (quantity + cost)
- Budget variance gauge/progress bar
- Year-over-year comparison cards

---

### 3. Conversion Funnel Analytics
**Goal:** Measure effectiveness of conversion paths

**Funnels to Track:**
1. **Service Discovery Funnel**
   - Homepage → Services Page → Service Detail → Contact Form
   - Conversion rate at each step
   - Drop-off percentages

2. **Doctor Profile Funnel**
   - Services Page → Doctor Profile → Appointment Request
   - Profile views → Contact clicks
   - Conversion rate

3. **Information Seeker Funnel**
   - Homepage → Informații Pacient → Facts → Contact
   - Educational content engagement
   - Conversion to patient inquiry

**Controller Implementation:**
```ruby
# Service Discovery Funnel
@funnel_service = {
  homepage: events.where("properties->>'url' = '/'").distinct.count(:visit_id),
  services_page: events.where("properties->>'url' LIKE '%/servicii-medicale%'").distinct.count(:visit_id),
  service_detail: events.where("properties->>'url' LIKE '%/servicii-medicale/%'").distinct.count(:visit_id),
  contact_form: events.where(name: 'submit', "properties->>'form' = 'contact'").distinct.count(:visit_id)
}

# Calculate conversion rates
@funnel_service_rates = @funnel_service.each_cons(2).map do |(step1, count1), (step2, count2)|
  { from: step1, to: step2, rate: (count2.to_f / count1 * 100).round(2) }
end
```

**View Design:**
- Funnel chart (narrowing visualization)
- Step-by-step conversion rates
- Highlight weakest conversion point in red

---

### 4. Content Performance Analytics
**Goal:** Identify most engaging content

**Metrics to Implement:**
- **Fact Page Performance**
  - Most viewed facts
  - Average time on page
  - Shares/likes (if social integration exists)
  - Bounce rate per fact

- **Service Page Effectiveness**
  - Views to contact conversion
  - Most engaging service descriptions
  - Services with lowest bounce rates

- **Blog Post Engagement** (if applicable)
  - Top performing posts
  - Read time vs actual time on page
  - Scroll depth tracking

**Controller Implementation:**
```ruby
# Fact Performance
@fact_performance = Fact.all.map do |fact|
  views = events.where("properties->>'url' LIKE ?", "%/informatii-pacient/#{fact.slug}%").count
  unique_visitors = events.where("properties->>'url' LIKE ?", "%/informatii-pacient/#{fact.slug}%")
                          .distinct.count(:visit_id)
  {
    fact: fact,
    views: views,
    unique_visitors: unique_visitors,
    engagement_rate: (unique_visitors.to_f / views * 100).round(2)
  }
end.sort_by { |f| -f[:views] }.first(10)

# Service Engagement
@service_engagement = MedicalService.all.map do |service|
  service_events = events.where("properties->>'url' LIKE ?", "%/servicii-medicale/#{service.slug}%")
  {
    service: service,
    views: service_events.count,
    avg_time: estimate_avg_time_on_page(service_events),
    bounce_rate: calculate_bounce_rate_for_page(service.slug)
  }
end.sort_by { |s| -s[:views] }.first(15)
```

**View Design:**
- Table with sortable columns (views, engagement, bounce rate)
- Bar chart: top facts by views
- Heatmap: service performance matrix

---

### 5. Technology Intelligence
**Goal:** Understand visitor technology landscape

**Metrics to Implement:**
- **Device Category Breakdown**
  - Desktop vs Mobile vs Tablet (% distribution)
  - Conversion rates by device type
  - Screen resolutions
  
- **Browser Insights**
  - Browser market share among visitors
  - Browser version distribution
  - Performance issues by browser (if tracking errors)
  
- **Operating System Analysis**
  - Windows vs macOS vs iOS vs Android
  - OS version distribution
  - Mobile OS dominance

**Controller Implementation:**
```ruby
# Already partially implemented in Phase 1
# Enhance with conversion rates

@device_conversion = @device_types.transform_values do |count|
  conversions = events.where(name: 'submit', device_type: device_type).distinct.count(:visit_id)
  {
    visits: count,
    conversions: conversions,
    conversion_rate: (conversions.to_f / count * 100).round(2)
  }
end

@browser_market_share = @browsers.transform_values do |count|
  {
    count: count,
    percentage: (count.to_f / @total_visits * 100).round(2)
  }
end
```

**View Design:**
- Pie chart: device type distribution
- Bar chart: browser market share
- Table: device-specific conversion rates

---

### 6. AI-Powered Insights & Recommendations
**Goal:** Provide actionable intelligence automatically

**Features to Implement:**
- **Anomaly Detection**
  - Alert when traffic drops > 30% vs previous period
  - Flag unusual bounce rate spikes
  - Identify page performance degradation
  
- **Predictive Analytics**
  - Forecast next month's traffic using linear regression
  - Predict peak hours for resource planning
  - Estimate seasonal trends
  
- **Recommendations Engine**
  - Suggest underperforming services to promote
  - Identify high-traffic pages missing CTAs
  - Recommend content updates for low-engagement pages

**Controller Implementation:**
```ruby
# Anomaly Detection
@anomalies = []

# Traffic drop alert
if @total_visits_change_pct < -30
  @anomalies << {
    type: 'warning',
    title: 'Scădere semnificativă a traficului',
    description: "Traficul a scăzut cu #{@total_visits_change_pct}% față de perioada anterioară.",
    severity: 'high'
  }
end

# Bounce rate spike
if @bounce_rate > 70 && @bounce_rate_change_pct > 20
  @anomalies << {
    type: 'warning',
    title: 'Bounce rate crescut',
    description: "Bounce rate este #{@bounce_rate}%, cu #{@bounce_rate_change_pct}% mai mare decât perioada anterioară.",
    severity: 'medium'
  }
end

# Traffic Forecast (Simple Moving Average)
recent_daily_data = @daily_visits.last(30).map { |d| d[:count] }
@forecast_next_7_days = recent_daily_data.sum / recent_daily_data.size * 7

# Recommendations
@recommendations = []

# Low-performing services
low_performing_services = @service_engagement.select { |s| s[:views] < 10 && s[:bounce_rate] > 80 }
if low_performing_services.any?
  @recommendations << {
    type: 'action',
    title: 'Servicii cu performanță scăzută',
    description: "#{low_performing_services.size} servicii au mai puțin de 10 vizualizări și bounce rate > 80%.",
    action: 'Considerați îmbunătățirea descrierii sau promovarea acestor servicii.'
  }
end
```

**View Design:**
- Alert cards at top of dashboard (red/yellow/green)
- Forecast line chart with confidence intervals
- Recommendations list with action buttons

---

## 🗂️ Implementation Plan

### Phase 2.1: Patient Journey & Behavior
**Estimated Time:** 2-3 hours
- Add visit path tracking
- Implement drop-off analysis
- Create journey visualization

### Phase 2.2: Medicine Consumption
**Estimated Time:** 1-2 hours
- Monthly trend charts
- Budget variance analysis
- YoY comparison

### Phase 2.3: Conversion Funnels
**Estimated Time:** 2-3 hours
- Define 3 key funnels
- Calculate conversion rates
- Create funnel visualizations

### Phase 2.4: Content Performance
**Estimated Time:** 1-2 hours
- Fact page analytics
- Service engagement metrics
- Top content identification

### Phase 2.5: Technology Intelligence
**Estimated Time:** 1 hour
- Enhance device/browser data
- Add conversion rates by device
- Market share visualizations

### Phase 2.6: AI Insights
**Estimated Time:** 2-3 hours
- Anomaly detection rules
- Traffic forecasting
- Recommendations engine

---

## 📦 Total Phase 2 Estimate

**Controller Work:** 6-8 hours  
**View Work:** 4-6 hours  
**Testing:** 2-3 hours  
**Total:** 12-17 hours (2-3 days)

---

## 🎯 Success Criteria

Phase 2 will be considered complete when:

- [ ] All 6 components implemented in controller
- [ ] Views created for each section
- [ ] Charts render correctly (Chart.js + custom)
- [ ] AI insights generate automatically
- [ ] Performance maintained (<100 queries, <500M memory)
- [ ] Documentation updated
- [ ] User testing completed

---

## 🚀 Next Steps

After Phase 2 completion:
- **Phase 3:** Advanced Segmentation (demographics, behavior cohorts)
- **Phase 4:** Export capabilities (PDF reports, Excel exports)
- **Phase 5:** Scheduled reports & email alerts

---

**Ready to proceed with Phase 2?** Let me know which section you'd like to tackle first!

---

**Created:** January 25, 2025  
**Author:** GitHub Copilot (Claude Sonnet 4.5)  
**Project:** Spinal Care RoR - Analytics Dashboard v2
