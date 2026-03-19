# Unimplemented Features

**Last Updated**: 2026-02-08
**Project**: Eureka HomeKit Dashboard

This document catalogs UI features that are present in the interface but not yet fully implemented with backend functionality or interactive behavior.

---

## Dashboard Features

### Activity Heatmap (Priority: High)
**Location**: `/` (Dashboard > List View)
**File**: `app/views/dashboards/show.html.erb:59-72`

**Current State**: Placeholder visualization with time range selector (Day/Week/Month buttons)

**Missing**:
- Data visualization implementation
- Time range filtering logic
- Historical activity data aggregation
- Chart rendering (consider Chart.js, D3.js, or Chartkick)

**UI Elements Present**:
- Time range selector with Day/Week/Month toggle buttons
- Bordered placeholder container with icon

---

### Device Connectivity Map (Priority: Medium)
**Location**: `/` (Dashboard > List View)
**File**: `app/views/dashboards/show.html.erb:74-85`

**Current State**: Placeholder with "ALL ONLINE" badge

**Missing**:
- Real-time connectivity status checking
- Network topology visualization
- Device ping/health monitoring
- Connection quality indicators
- Historical uptime tracking

**UI Elements Present**:
- Status badge showing "ALL ONLINE"
- Placeholder container

---

### System Load Stat (Priority: Low)
**Location**: `/` (Dashboard > List View)
**File**: `app/views/dashboards/show.html.erb:53`

**Current State**: Hardcoded value "1.2"

**Missing**:
- Actual system load calculation (CPU, memory, etc.)
- Dynamic data source
- Rails server performance metrics integration

---

## Dashboard Controls

### Filter Button (Priority: Medium)
**Location**: `/` (Dashboard)
**File**: `app/views/dashboards/show.html.erb:29-32`

**Current State**: Button renders but has no action handler

**Missing**:
- Filter modal/dropdown implementation
- Filter criteria (date range, room, sensor type, event type)
- Applied filter state management
- Filter persistence across page loads

---

## Events Page

### Export CSV (Priority: Medium)
**Location**: `/events`
**File**: `app/views/events/index.html.erb:18-21`

**Current State**: Button renders without functionality

**Missing**:
- CSV generation logic (consider using CSV library)
- Column selection interface
- Date range export options
- Download file handler
- Background job for large exports

---

### Load More Events (Priority: Medium)
**Location**: `/events` (bottom of event table)
**File**: `app/views/events/index.html.erb:64-67`

**Current State**: Button visible when events exceed 50, no pagination

**Missing**:
- Pagination or infinite scroll implementation
- Dynamic loading of additional events
- State management for loaded events
- Performance optimization for large datasets

---

## Sensor Detail Page

### Favorite Button (Priority: Low)
**Location**: `/sensors/:id`
**File**: `app/views/sensors/show.html.erb:20-23`

**Current State**: Button renders without action

**Missing**:
- User favorites model/association
- Toggle favorite state functionality
- Favorites filtering on sensors index
- Visual indicator for favorited sensors

---

### Set Alert (Priority: High)
**Location**: `/sensors/:id`
**File**: `app/views/sensors/show.html.erb:24-27`

**Current State**: Button renders without action

**Missing**:
- Alert configuration modal/form
- Alert rules engine (threshold, change detection, offline detection)
- Notification delivery system (email, push, SMS)
- Alert history and management interface
- Alert model and database schema

---

## Room Detail Page

### Room Settings (Priority: Low)
**Location**: `/rooms/:id`
**File**: `app/views/rooms/show.html.erb:28-31`

**Current State**: Button renders without action

**Missing**:
- Room configuration modal/page
- Editable room properties (name, icon, color)
- Room grouping/organization features
- Room assignment to floor/area

---

## Homes Page

### Add Home (Priority: Low)
**Location**: `/homes`
**File**: `app/views/homes/index.html.erb:18-21`

**Current State**: Button renders without action

**Missing**:
- Manual home creation form (if needed beyond sync)
- Home configuration options
- Multi-home setup workflow
- Validation and error handling

**Note**: May be intentionally non-functional if homes are only synced from HomeKit bridge.

---

## Navigation & Settings

### Settings Link (Priority: Medium)
**Location**: Left sidebar
**File**: `app/components/layouts/left_sidebar_component.rb:17`

**Current State**: Link points to `#` (no-op)

**Missing**:
- Settings page/route
- Application configuration interface
- User preferences management
- Theme customization
- Notification preferences
- Integration settings (HomeKit bridge configuration)

---

### User Profile Menu Items (Priority: Low)
**Location**: Header dropdown menu
**File**: `app/components/layouts/header_component.html.erb:44-46`

**Current State**: Dropdown menu items render but have no routes

**Missing Links**:
- Profile page (`/profile` or `/users/edit`)
- Settings page (`/settings`)
- Logout functionality (`/logout`)

**Missing**:
- User authentication system (Devise, etc.)
- User model and sessions
- Profile editing interface
- Account management features

---

## Real-Time Features

### Event Detail Modal (Priority: Medium)
**Location**: `/events` (Events index page)
**File**: `app/views/events/index.html.erb:74`

**Current State**: Component is rendered but likely not triggered

**Missing**:
- Modal trigger on event row click
- Event detail display with full metadata
- Related events/context display
- Modal state management (Stimulus controller)

---

## Additional Notes

### Routes Not Implemented
Per `config/routes.rb:30-31`, the following resource actions are defined but may lack corresponding controller methods or views:

**Potentially Missing**:
- Homes show page functionality (route exists at `/homes/:id`)
- Sensors show page full functionality
- Events show page (route exists but may be unused if modal is preferred)

### Search Functionality
**Files**: `app/components/shared/search_bar_component.html.erb`, left sidebar search

**Current State**: Search input renders but likely non-functional

**Missing**:
- Global search implementation
- Search results page
- Search indexing (consider pg_search or ElasticSearch)
- Auto-complete suggestions
- Search filters

---

## Implementation Priority Summary

### High Priority (Core Functionality)
1. **Activity Heatmap** - Key dashboard feature for room activity visualization
2. **Set Alert** - Critical for proactive monitoring and notifications
3. **Event Detail Modal** - Important for debugging and detailed event inspection

### Medium Priority (Enhanced UX)
4. **Export CSV** - Data export for analysis
5. **Load More Events** - Pagination for large event logs
6. **Filter Button** - Dashboard and event filtering
7. **Device Connectivity Map** - Network health monitoring
8. **Settings Page** - Application configuration

### Low Priority (Nice-to-Have)
9. **Favorite Sensors** - User personalization
10. **Room Settings** - Room customization
11. **Add Home** - May not be needed if sync-only
12. **User Profile** - Account management (depends on auth requirements)
13. **System Load** - Server performance monitoring

---

## Technical Recommendations

### For Visualization Components
- Consider using **Chartkick** with Chart.js for Ruby-friendly charting
- Use **ViewComponent** pattern already established in the project
- Implement Stimulus controllers for interactive chart controls

### For Background Jobs
- Use **Sidekiq** or **Solid Queue** for CSV exports and alert processing
- Implement job status tracking for long-running exports

### For Alerts & Notifications
- Create `Alert` and `AlertRule` models
- Use ActionMailer for email notifications
- Consider integrating with services like Twilio (SMS) or APNs (push)

### For Search
- Start with simple SQL LIKE queries for initial implementation
- Upgrade to **pg_search** gem for full-text search
- Consider ElasticSearch for large-scale deployments

---

## Related Documentation
- [Epic 2 Implementation Status](epics/Epic-2-UI/0001-IMPLEMENTATION-STATUS.md)
- [Epic 3 Floorplan Features](epics/wip/Floorplan/Epic-3/0000-overview-floorplan.md)
