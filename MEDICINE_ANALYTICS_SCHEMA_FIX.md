# Medicine Analytics Schema Alignment - Fix Summary

## Date: 2026-01-26
## Branch: new-analytics

## Problem Overview

The medicine consumption analytics section was displaying errors due to schema mismatches. The view and Chart.js code were built assuming a detailed transaction tracking system with budget management, but the actual `medicines_consumptions` table only tracks monthly consumption totals.

### Database Schema Reality

**MedicinesConsumption Table (Actual)**:
- `id` (integer)
- `month` (string)
- `year` (integer)
- `consumption` (decimal)
- `created_at` (timestamp)
- `updated_at` (timestamp)

**Missing Columns (Assumed by old code)**:
- `total_amount` - NOT IN SCHEMA
- `budget` - NOT IN SCHEMA
- `medicine_name` - NOT IN SCHEMA
- `quantity` - NOT IN SCHEMA
- `transaction_date` - NOT IN SCHEMA

## Fixes Applied

### 1. Controller Query Alignment (Commits: 1b1a18d, 0a1ffee)

**File**: `app/controllers/admin_controller.rb`

#### Medicine Monthly Trends
```ruby
# Lines 498-503
@medicine_monthly = MedicinesConsumption.where('created_at >= ?', 12.months.ago)
                                        .group("DATE_TRUNC('month', created_at)")
                                        .select(Arel.sql("DATE_TRUNC('month', created_at) as month, 
                                                SUM(consumption) as total_consumption,
                                                COUNT(*) as record_count"))
                                        .order('month ASC')
```
**Changed**: Uses `.sum(:consumption)` instead of querying non-existent `total_amount`  
**Returns**: `total_consumption` and `record_count` (NOT `total_spent`, `total_budget`, `transaction_count`)

#### Current Month Stats
```ruby
# Lines 507-509
@current_month_consumption = MedicinesConsumption.where('created_at >= ?', current_month_start).sum(:consumption)
@current_month_variance = 0  # Budget tracking not available
```
**Changed**: Uses `sum(:consumption)` instead of accessing `total_amount` column  
**Note**: Variance calculation disabled (requires budget data)

#### Year-over-Year Comparison
```ruby
# Lines 512-518
current_year_consumption = MedicinesConsumption.where('EXTRACT(YEAR FROM created_at) = ?', Date.today.year)
                                               .sum(:consumption)
previous_year_consumption = MedicinesConsumption.where('EXTRACT(YEAR FROM created_at) = ?', Date.today.year - 1)
                                                .sum(:consumption)
@medicine_yoy_change = calculate_percentage_change(current_year_consumption, previous_year_consumption)
@current_year_consumption = current_year_consumption
@previous_year_consumption = previous_year_consumption
```
**Changed**: Uses `sum(:consumption)` instead of accessing `total_amount`  
**Variables**: `@current_year_consumption` and `@previous_year_consumption` (NOT `@current_year_spend`, `@previous_year_spend`)

#### Top Medicines (Disabled)
```ruby
# Lines 520-522
@top_medicines = []  # medicine_name column doesn't exist in schema
```
**Changed**: Disabled query entirely - returns empty array  
**Reason**: Requires `medicine_name` column which doesn't exist

#### Budget Compliance (Disabled)
```ruby
# Lines 534-535
@budget_compliance_rate = 0  # budget column doesn't exist in schema
```
**Changed**: Hardcoded to 0  
**Reason**: Requires `budget` column which doesn't exist

### 2. View Variable Alignment (Commit: 53a0390)

**File**: `app/views/admin/analytics.html.erb`

#### Current Month Card (Lines 520-540)
```erb
<div class="chart-card">
  <div class="chart-header">
    <h3 class="chart-title">Luna Curentă - Consum</h3>
  </div>
  <div class="chart-body">
    <div class="budget-overview">
      <div class="budget-row">
        <span class="budget-label">Consum Total:</span>
        <span class="budget-value"><%= number_to_currency(@current_month_consumption, unit: 'RON ') %></span>
      </div>
    </div>
    <div class="forecast-box">
      <div class="forecast-label">Media Lunară (6 luni):</div>
      <div class="forecast-value"><%= number_to_currency(@avg_monthly_spend, unit: 'RON ') %></div>
    </div>
  </div>
</div>
```
**Changed**: Uses `@current_month_consumption` instead of `@current_month_spend`  
**Changed**: Removed budget vs actual comparison (budget data unavailable)  
**Changed**: Card title from spending focus to consumption focus

#### Year-over-Year Card (Lines 563-575)
```erb
<div class="yoy-comparison">
  <div class="yoy-year">
    <div class="yoy-label"><%= Date.today.year - 1 %></div>
    <div class="yoy-amount"><%= number_to_currency(@previous_year_consumption, unit: 'RON ') %></div>
  </div>
  <div class="yoy-arrow <%= @medicine_yoy_change >= 0 ? 'yoy-up' : 'yoy-down' %>">
    <%= @medicine_yoy_change >= 0 ? '↑' : '↓' %>
    <span><%= @medicine_yoy_change.abs %>%</span>
  </div>
  <div class="yoy-year">
    <div class="yoy-label"><%= Date.today.year %></div>
    <div class="yoy-amount"><%= number_to_currency(@current_year_consumption, unit: 'RON ') %></div>
  </div>
</div>
```
**Changed**: Uses `@current_year_consumption` / `@previous_year_consumption` instead of `@current_year_spend` / `@previous_year_spend`  
**Changed**: Uses `@medicine_yoy_change` for percentage arrow

### 3. Chart.js Data Field Updates (Commits: 2e9e071, a168c07)

**File**: `app/views/admin/analytics.html.erb` (Lines 1695-1730)

#### Fixed Dataset Configuration
```javascript
new Chart(medicineMonthlyCtx, {
  type: 'line',
  data: {
    labels: [
      <% @medicine_monthly.each do |record| %>
        '<%= Date.parse(record.month.to_s).strftime('%b %Y') %>',  // Parse string to Date
      <% end %>
    ],
    datasets: [
      {
        label: 'Consum Total',  // Was: 'Cheltuieli Reale'
        data: [
          <% @medicine_monthly.each do |record| %>
            <%= record.total_consumption %>,  // Was: record.total_spent
          <% end %>
        ],
        borderColor: '#3b82f6',
        backgroundColor: 'rgba(59, 130, 246, 0.1)',
        yAxisID: 'y'
      },
      {
        label: 'Număr Înregistrări',  // Was: 'Număr Tranzacții'
        data: [
          <% @medicine_monthly.each do |record| %>
            <%= record.record_count %>,  // Was: record.transaction_count
          <% end %>
        ],
        type: 'bar',
        backgroundColor: 'rgba(16, 185, 129, 0.3)',
        yAxisID: 'y1'
      }
      // Removed third dataset (Budget) that used record.total_budget
    ]
  },
  options: {
    scales: {
      y: {
        title: { text: 'Consum (RON)' }  // Was: 'Cost (RON)'
      },
      y1: {
        title: { text: 'Înregistrări' }  // Was: 'Tranzacții'
      }
    },
    plugins: {
      tooltip: {
        callbacks: {
          label: function(context) {
            if (context.datasetIndex === 1) {  // Was: === 2
              return context.parsed.y + ' înregistrări';  // Was: 'tranzacții'
            } else {
              return context.parsed.y.toLocaleString('ro-RO') + ' RON';
            }
          }
        }
      }
    }
  }
});
```

**Changes Summary**:
1. **Month parsing**: Added `Date.parse(record.month.to_s).strftime('%b %Y')` - `month` field returns string, not Date
2. **Dataset 1**: `record.total_spent` → `record.total_consumption`, label changed
3. **Dataset 2**: `record.transaction_count` → `record.record_count`, label updated to "Înregistrări"
4. **Dataset 3**: Removed entirely (budget comparison using `record.total_budget`)
5. **Y-axis labels**: Changed from "Cost/Tranzacții" to "Consum/Înregistrări"
6. **Tooltip**: Updated `datasetIndex === 2` → `=== 1` (only 2 datasets now)

## Testing Results

### Success Criteria Met
- ✅ Analytics page loads with HTTP 200 OK
- ✅ No `NoMethodError` for undefined column access
- ✅ No `undefined method 'strftime'` errors
- ✅ Chart.js renders with 2 datasets (consumption + count)
- ✅ All controller variables match view references
- ✅ Monthly consumption data displays correctly

### Test Output
```
Completed 200 OK in 1941ms
```

## Database Implications

### What We CAN Track
- **Monthly consumption totals** (in RON)
- **Record count** per month
- **Year-over-year consumption trends**
- **Average monthly consumption** (6-month rolling)

### What We CANNOT Track (Schema Limitations)
- ❌ Budget vs actual comparisons
- ❌ Individual medicine names/categories
- ❌ Transaction-level detail (quantity, unit price, date)
- ❌ Top spending by medicine/category
- ❌ Daily/weekly granularity

## Future Considerations

### If Detailed Tracking Needed
To restore full analytics functionality, a database migration would be required:

```ruby
# Hypothetical migration - NOT APPLIED
class AddDetailedFieldsToMedicinesConsumptions < ActiveRecord::Migration[8.0]
  def change
    add_column :medicines_consumptions, :medicine_name, :string
    add_column :medicines_consumptions, :quantity, :decimal
    add_column :medicines_consumptions, :unit_price, :decimal
    add_column :medicines_consumptions, :total_amount, :decimal
    add_column :medicines_consumptions, :budget, :decimal
    add_column :medicines_consumptions, :transaction_date, :date
  end
end
```

**Note**: Current implementation works correctly with existing simple schema.

## Commits Applied

1. **ebb1bc2**: Fix click analytics to include both 'click' and '$click' events
2. **b7fa63f**: Wrap JSON operators in Arel.sql() for Rails 8 compatibility
3. **0308cb5**: Wrap aggregate functions in Arel.sql() for Rails 8
4. **1b1a18d**: Update MedicinesConsumption queries to use consumption column
5. **0a1ffee**: Remove budget compliance calculation (budget column doesn't exist)
6. **283ecf7**: Fix ERB syntax error in heatmap intensity calculation
7. **53a0390**: Update view variables to match controller (@current_month_consumption, etc.)
8. **2e9e071**: Update Chart.js to use correct field names (total_consumption, record_count)
9. **a168c07**: Parse month string to Date for strftime in Chart.js labels

## Files Modified

- `app/controllers/admin_controller.rb` - Lines 498-535
- `app/views/admin/analytics.html.erb` - Lines 520-575, 1695-1800

## Branch Status

All changes committed and pushed to `new-analytics` branch.  
Analytics page fully functional with current schema.
