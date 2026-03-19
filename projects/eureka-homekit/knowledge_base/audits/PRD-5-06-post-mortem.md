# PRD-5-06 Lock Controls - Principal Architect Security & Code Quality Review

**Reviewer**: Principal Architect (Claude 4.5)  
**Review Date**: February 14, 2026  
**Implementation**: PRD-5-06 Lock Controls  
**Epic**: Epic 5 - Interactive HomeKit Device Controls

---

## 🎯 EXECUTIVE SUMMARY

**Safety Score: 5/10** ⚠️  
**Maintainability Grade: C+** 📊  
**Status: CONDITIONAL PASS - MAJOR ISSUES IDENTIFIED**

PRD-5-06 demonstrates good UI/UX patterns and basic security awareness, but contains **THREE CRITICAL SECURITY VIOLATIONS** against the Epic 5 Strict Directive. These must be resolved before implementing Garage Door controls (PRD-5-07), as garage doors present even greater physical security risks.

---

## 🔒 CRITICAL SECURITY FINDINGS

### 🚨 CRITICAL #1: Open3.capture3 MISUSE (High Severity)
**File**: `app/services/prefab_client.rb:114-119`  
**Epic 5 Strict Directive Violation**: Section 1 (Security & Command Safety)

**Issue**:
```ruby
stdin, stdout, stderr, wait_thr = Open3.capture3(*args)
# ...
result = stdout.read  # ❌ WRONG - stdout is already a String
error = stderr.read   # ❌ WRONG - stderr is already a String
```

**What the Directive Requires**:
> "ALL external calls (e.g., `curl` to Prefab API) MUST use `Open3.capture3` or `Open3.capture2e`."

**The Problem**:
`Open3.capture3(*args)` returns **THREE STRINGS** (stdout, stderr, wait_thr), NOT IO objects. Calling `.read` on a String raises `NoMethodError`, causing **100% failure rate** for all lock control commands.

**Correct Implementation**:
```ruby
stdout, stderr, wait_thr = Open3.capture3(*args)
success = wait_thr.success?
latency = ((Time.now - start_time) * 1000).round(2)

result = stdout  # Already a String
error = stderr   # Already a String
```

**Impact**:
- **Every lock/unlock attempt fails silently**
- No error surfaced to user (rescued as generic "Control failed")
- ControlEvent logs show `success=false` with misleading error messages
- Locks cannot be operated via web UI

**Why This Wasn't Caught**:
- No integration tests for `PrefabClient.update_characteristic`
- Only unit tests for component state rendering exist
- WebMock stubs bypass the actual Open3 execution path

---

### 🚨 CRITICAL #2: MISSING WEBHOOK DEDUPLICATION (High Severity)
**File**: `app/controllers/api/homekit_events_controller.rb`  
**Epic 5 Strict Directive Violation**: Section 3 (Deduplication & Echo Prevention)

**What the Directive Requires**:
> "Before processing incoming webhook events, check for recent control events (same accessory + characteristic, within 2–5 seconds)."  
> "Skip creation if a matching recent outbound control exists → prevents feedback loops."

**The Problem**:
The webhook controller (`HomekitEventsController#handle_sensor_event`) has NO echo prevention logic. When a user clicks "Lock" in the UI:

1. **Outbound**: Rails → PrefabClient → HomeKit (Lock Target State = 1)
2. **Inbound**: HomeKit → Prefab → Rails webhook (Lock Target State = 1)
3. **Result**: HomekitEvent created for the SAME command we just sent

**Attack Surface**:
- **Feedback loops**: If Prefab echoes control commands instantly (< 100ms), rapid clicking could create oscillating lock/unlock commands
- **Audit pollution**: ControlEvent and HomekitEvent tables both log the same action, inflating metrics
- **Race conditions**: Optimistic UI updates conflict with webhook-triggered state changes

**Missing Implementation**:
```ruby
def should_store_event?(sensor, new_value, timestamp)
  return true if sensor.nil?
  return true if sensor.current_value.nil?
  
  # VALUE CHANGE CHECK (exists)
  return false if sensor.current_value.to_s == new_value.to_s
  
  # MISSING: ECHO PREVENTION CHECK
  # Check for recent outbound control within 2-5 seconds
  accessory = sensor.accessory
  recent_control = ControlEvent
    .where(accessory_id: accessory.id)
    .where(characteristic_name: sensor.characteristic_type)
    .where('created_at >= ?', 5.seconds.ago)
    .where(new_value: new_value.to_s)
    .exists?
  
  return false if recent_control # Skip webhook event if we just sent this command
  
  true
end
```

**Impact**:
- Moderate risk for locks (physical operation takes 1-2 seconds)
- **HIGH RISK for garage doors** (PRD-5-07) where rapid open/close could cause mechanical damage

---

### 🚨 CRITICAL #3: NO TIMEOUT ON Open3 CALL (Medium Severity)
**File**: `app/services/prefab_client.rb:110-114`  
**Epic 5 Strict Directive Violation**: Section 1 (Security & Command Safety)

**What the Directive Requires**:
> "Every Open3 call MUST include a timeout (e.g., `timeout: 5.seconds`) to prevent zombie processes."

**Current Code**:
```ruby
args = ['curl', '-s', "-m#{WRITE_TIMEOUT / 1000.0}", '-X', method, '-H', 'Content-Type: application/json']
stdin, stdout, stderr, wait_thr = Open3.capture3(*args)
```

**The Problem**:
- `curl -m5.0` sets a timeout **inside curl**, but `Open3.capture3` itself has NO timeout
- If curl hangs on DNS resolution, socket creation, or signal handling, the Ruby process waits indefinitely
- **Zombie processes** accumulate under heavy load

**Correct Implementation**:
```ruby
require 'timeout'

Timeout.timeout(WRITE_TIMEOUT / 1000.0 + 1) do
  stdout, stderr, wait_thr = Open3.capture3(*args)
  # ... process result
end
```

**OR** (preferred for Rails):
```ruby
stdout, stderr, wait_thr = Open3.capture3(*args, timeout: 5)
```

**Impact**:
- Puma worker threads blocked indefinitely
- Under sustained attack, all workers exhausted → denial of service
- Lock commands hang forever with no user feedback

---

## ⚠️ MAJOR QUALITY ISSUES

### MAJOR #1: MISSING IP ADDRESS LOGGING
**File**: `app/controllers/accessories_controller.rb:24`  
**Epic 5 Strict Directive**: Section 2 (Audit & Traceability)

**What the Directive Requires**:
> "Is the client IP address (request.remote_ip) correctly passed from the controller through to the ControlEvent log?"

**Current Implementation**: ✅ **CORRECT**
```ruby
result = PrefabControlService.set_characteristic(
  accessory: @accessory,
  characteristic: params[:characteristic],
  value: value,
  user_ip: request.remote_ip,  # ✅ Correctly passed
  source: 'web'
)
```

**Verification**:
- IP address flows correctly to `ControlEvent.user_ip`
- All lock/unlock attempts will be traceable to originating IP
- Meets compliance requirement

**Grade**: ✅ **PASS**

---

### MAJOR #2: MISSING REQUEST_ID IN OPEN3 CONTEXT
**File**: `app/services/prefab_client.rb:107-132`  
**Epic 5 Strict Directive**: Section 2 (Audit & Traceability)

**What the Directive Requires**:
> "Every write attempt MUST generate a unique `SecureRandom.uuid` as `request_id`."

**Current Implementation**:
- `request_id` is generated in `PrefabControlService.create_control_event` ✅
- BUT: `PrefabClient.execute_curl_base` does NOT log the `request_id` ❌

**The Problem**:
When troubleshooting a failed lock command, the Rails logs show:
```
PrefabClient: curl PUT failed with exit code 7
PrefabClient: curl error output: Could not resolve host
```

But there's NO `request_id` linking this to the specific `ControlEvent` record. You cannot correlate:
- User action (ControlEvent with request_id=abc-123)
- Low-level failure (PrefabClient log with no request_id)

**Recommended Fix**:
```ruby
# In PrefabControlService
def self.set_characteristic(accessory:, characteristic:, value:, user_ip: nil, source: 'web')
  request_id = SecureRandom.uuid  # Generate ONCE at top
  
  # Pass to PrefabClient
  result = PrefabClient.update_characteristic(
    home, room, accessory_name, characteristic, value,
    request_id: request_id  # NEW: Thread request_id through
  )
  
  # Log to ControlEvent with same request_id
  create_control_event(..., request_id: request_id)
end

# In PrefabClient
def self.execute_curl_base(url, method:, payload: nil, request_id: nil)
  Rails.logger.info("PrefabClient [#{request_id}]: #{method} #{url}")
  # ... existing code
  unless success
    Rails.logger.error("PrefabClient [#{request_id}]: curl failed")
  end
end
```

**Impact**:
- Debugging lock failures requires cross-referencing timestamps (slow, error-prone)
- Cannot trace multi-step failures (e.g., lock → retry → retry → final failure)

---

### MAJOR #3: JAMMED STATE NOT TERMINAL IN UI
**File**: `app/components/controls/lock_control_component.html.erb:36-42`  
**Epic 5 Strict Directive**: Section 4 (Hardware Safety)

**What the Directive Requires**:
> "Does the UI correctly handle the 'Jammed' state (2) as a terminal error?"

**Current Implementation**:
```erb
<% if jammed? %>
  <button class="btn btn-ghost"
          disabled
          title="Lock is jammed - manual intervention required">
    🔧
  </button>
<% end %>
```

**The Problem**:
- Jammed state (2) shows a **disabled wrench icon** ✅
- BUT: If `current_state == 2`, the UI ALSO shows "Lock" or "Unlock" button based on `locked?` helper:

```ruby
def locked?
  current_state == 1
end
```

**Result**:
- When `current_state == 2` (jammed), `locked?` returns `false`
- UI renders "Lock" button (enabled) ALONGSIDE the disabled wrench icon
- User can still ATTEMPT to lock/unlock a jammed mechanism

**Correct Logic**:
```erb
<% if jammed? %>
  <!-- Show ONLY the error state, no action buttons -->
  <div class="alert alert-error">
    <span>🔧 Lock is jammed - manual intervention required</span>
  </div>
<% else %>
  <!-- Normal lock/unlock buttons -->
  <% if locked? %>
    <button class="btn btn-warning" ...>Unlock</button>
  <% else %>
    <button class="btn btn-primary" ...>Lock</button>
  <% end %>
<% end %>
```

**Impact**:
- User can send lock commands to jammed hardware (mechanical stress)
- No clear indication that the lock is in a non-operational state
- For garage doors (PRD-5-07), this could cause damage to motor/track

---

## ✅ COMPLIANT IMPLEMENTATIONS

### PASS #1: Boolean Coercion for Lock Target State
**File**: `app/controllers/accessories_controller.rb:73-75`  
**Epic 5 Strict Directive**: Section 4 (Data Handling & Coercion)

```ruby
when 'Lock Target State'
  # Coerce lock target state to integer (0=unsecured, 1=secured)
  value.to_i
```

**Grade**: ✅ **PASS**  
Correctly coerces incoming values to integer. Lock controls send `0` or `1` explicitly, so no truthy/falsy edge cases apply.

---

### PASS #2: Frontend Double-Click Prevention
**File**: `app/javascript/controllers/lock_control_controller.js:14-22`  
**Epic 5 Strict Directive**: Frontend Safety

```javascript
connect() {
  this.debounceTimer = null
  this.isProcessing = false
}

lock(event) {
  if (this.offlineValue || this.isProcessing) return  // ✅ Guard clause
  
  this.isProcessing = true  // ✅ Atomic flag
  const button = event.currentTarget
  button.disabled = true    // ✅ Disable button
```

**Grade**: ✅ **PASS**  
- `isProcessing` flag prevents concurrent requests
- Button disabled during operation
- Offline check prevents commands to unreachable accessories

**Improvement Opportunity**:
Add a **timeout** to reset `isProcessing` if the API call hangs:
```javascript
setTimeout(() => {
  if (this.isProcessing) {
    this.isProcessing = false
    button.disabled = false
    this.showError('Request timed out')
  }
}, 10000)  // 10-second timeout
```

---

### PASS #3: Confirmation Modal for Unlock
**File**: `app/components/controls/lock_control_component.html.erb:44-65`  
**Epic 5 Strict Directive**: Frontend Safety

```erb
<dialog data-lock-control-target="confirmDialog" class="modal">
  <div class="modal-box">
    <h3 class="font-bold text-lg">Confirm Unlock</h3>
    <p class="py-4">Are you sure you want to unlock...?</p>
    <div class="modal-action">
      <button data-action="click->lock-control#cancelUnlock">Cancel</button>
      <form data-action="click->lock-control#confirmUnlock">
        <button class="btn btn-warning">Unlock</button>
      </form>
    </div>
  </div>
</dialog>
```

**Grade**: ✅ **PASS**  
- Native `<dialog>` element with backdrop
- Unlock requires explicit confirmation
- Lock operation has no confirmation (appropriate for security-enhancing action)

**Bypass-Proof Analysis**:
- ✅ Modal is NOT triggered by direct API call (must click showUnlockConfirmation first)
- ✅ `confirmDialog.showModal()` blocks UI (modal backdrop)
- ✅ JavaScript console bypass would still require valid CSRF token

**Minor Concern**:
The `<form method="dialog">` wrapper on the Unlock button is unusual. Verify this doesn't accidentally submit a form and reload the page.

---

### PASS #4: Retry Logic with Fixed Sleep
**File**: `app/services/prefab_control_service.rb:15-18`  
**Epic 5 Strict Directive**: Section 5 (Retry & Resilience)

```ruby
(MAX_ATTEMPTS - 1).times do
  break if result[:success]
  sleep(RETRY_DELAY)  # 0.5 seconds
  result = attempt_set_characteristic(home, room, accessory_name, characteristic, value)
end
```

**Grade**: ✅ **PASS**  
- Exactly 3 attempts with 500ms fixed sleep (not exponential)
- Breaks early on success
- Final failure logged to ControlEvent with `success=false`

---

## 📊 TEST COVERAGE ANALYSIS

### Component Tests (spec/components/controls/lock_control_component_spec.rb)
**Coverage**: 12 examples, 0 failures  
**Grade**: B+

**What's Tested**:
✅ State mapping (current_state, target_state)  
✅ State predicates (locked?, unlocked?, jammed?, unknown?)  
✅ State icons and text  
✅ Offline detection  

**What's MISSING**:
❌ **No integration tests for control flow**  
❌ **No WebMock stubs for PrefabClient**  
❌ **No controller tests for AccessoriesController#control**  
❌ **No test for jammed state UI rendering**  
❌ **No test for echo prevention (because it doesn't exist)**

### Recommended Test Additions

#### 1. Controller Integration Test
```ruby
# spec/requests/accessories_controller_spec.rb
RSpec.describe "Lock Control API", type: :request do
  let(:accessory) { create(:accessory, :lock) }
  
  it "locks the door and logs control event" do
    stub_request(:put, /#{ENV['PREFAB_API_URL']}/).to_return(status: 200)
    
    post '/accessories/control', params: {
      accessory_id: accessory.uuid,
      characteristic: 'Lock Target State',
      value: 1
    }
    
    expect(response).to have_http_status(:ok)
    expect(ControlEvent.last).to have_attributes(
      accessory: accessory,
      characteristic_name: 'Lock Target State',
      new_value: '1',
      success: true,
      user_ip: '127.0.0.1',
      source: 'web'
    )
  end
  
  it "handles jammed state gracefully" do
    # Simulate HomeKit rejecting command because lock is jammed
    stub_request(:put, /#{ENV['PREFAB_API_URL']}/).to_return(
      status: 500,
      body: '{"error": "Lock mechanism jammed"}'
    )
    
    post '/accessories/control', params: {
      accessory_id: accessory.uuid,
      characteristic: 'Lock Target State',
      value: 1
    }
    
    expect(response).to have_http_status(:internal_server_error)
    expect(ControlEvent.last.success).to be false
    expect(ControlEvent.last.error_message).to include('jammed')
  end
end
```

#### 2. Echo Prevention Test
```ruby
it "skips webhook event if recent control event exists" do
  # User clicks "Lock" in UI
  ControlEvent.create!(
    accessory: accessory,
    characteristic_name: 'Lock Target State',
    new_value: '1',
    success: true,
    source: 'web',
    created_at: 2.seconds.ago
  )
  
  # Prefab echoes the same event via webhook
  post '/api/homekit/events', params: {
    type: 'characteristic_updated',
    accessory: accessory.name,
    characteristic: 'Lock Target State',
    value: '1',
    timestamp: Time.current.iso8601
  }, headers: { 'Authorization' => "Bearer #{Rails.application.credentials.prefab_webhook_token}" }
  
  # Event should NOT be stored (deduplicated)
  expect(HomekitEvent.count).to eq(0)
  
  # But sensor state should still be updated
  accessory.reload
  expect(accessory.sensors.find_by(characteristic_type: 'Lock Target State').current_value).to eq('1')
end
```

#### 3. Jammed State UI Test (System Test)
```ruby
# spec/system/lock_control_spec.rb
RSpec.describe "Lock Control UI", type: :system, js: true do
  it "disables all actions when lock is jammed" do
    accessory = create(:accessory, :lock_jammed)
    visit home_path(accessory.home)
    
    within "#accessory_#{accessory.id}" do
      expect(page).to have_text("Jammed")
      expect(page).to have_css("button[disabled]", count: 1)  # Only wrench icon
      expect(page).not_to have_button("Lock")
      expect(page).not_to have_button("Unlock")
    end
  end
end
```

---

## 🎯 MANDATORY CHANGES FOR PRD-5-07 (GARAGE DOORS)

Before implementing Garage Door controls, the following MUST be resolved:

### 1. Fix Open3.capture3 Misuse ⚠️ CRITICAL
**Priority**: P0 (Blocking)  
**Estimated Effort**: 15 minutes  
**Test Required**: Integration test with actual curl execution

```ruby
# app/services/prefab_client.rb:114-119
stdout, stderr, wait_thr = Open3.capture3(*args)  # Remove stdin
success = wait_thr.success?
latency = ((Time.now - start_time) * 1000).round(2)

result = stdout  # Remove .read
error = stderr   # Remove .read
```

### 2. Implement Webhook Echo Prevention ⚠️ CRITICAL
**Priority**: P0 (Blocking)  
**Estimated Effort**: 2 hours  
**Test Required**: Controller integration test with stubbed ControlEvent

```ruby
# app/controllers/api/homekit_events_controller.rb
ECHO_PREVENTION_WINDOW = 5.seconds

def should_store_event?(sensor, new_value, timestamp)
  return true if sensor.nil? || sensor.current_value.nil?
  return false if sensor.current_value.to_s == new_value.to_s
  
  # Check for recent outbound control (echo prevention)
  accessory = sensor.accessory
  recent_control = ControlEvent
    .where(accessory_id: accessory.id)
    .where(characteristic_name: sensor.characteristic_type)
    .where('created_at >= ?', ECHO_PREVENTION_WINDOW.ago)
    .where(new_value: new_value.to_s)
    .exists?
  
  !recent_control  # Store event ONLY if no recent control
end
```

### 3. Add Open3 Timeout ⚠️ HIGH
**Priority**: P1 (Before PRD-5-07)  
**Estimated Effort**: 30 minutes  
**Test Required**: Timeout simulation test

```ruby
# app/services/prefab_client.rb
require 'timeout'

def self.execute_curl_base(url, method:, payload: nil)
  start_time = Time.now
  begin
    Timeout.timeout((WRITE_TIMEOUT / 1000.0) + 1) do
      args = ['curl', '-s', "-m#{WRITE_TIMEOUT / 1000.0}", ...]
      stdout, stderr, wait_thr = Open3.capture3(*args)
      # ... rest of method
    end
  rescue Timeout::Error
    Rails.logger.error("PrefabClient: curl #{method} timed out after #{WRITE_TIMEOUT}ms")
    ['', false, (WRITE_TIMEOUT / 1000.0) * 1000, nil]
  end
end
```

### 4. Fix Jammed State UI Logic ⚠️ HIGH
**Priority**: P1 (Before PRD-5-07)  
**Estimated Effort**: 30 minutes  
**Test Required**: System test with Capybara

```erb
<!-- app/components/controls/lock_control_component.html.erb -->
<% if jammed? %>
  <div class="alert alert-error">
    <span>🔧 Lock is jammed - manual intervention required</span>
  </div>
<% elsif unknown? %>
  <div class="alert alert-warning">
    <span>❓ Lock state unknown</span>
  </div>
<% else %>
  <!-- Normal lock/unlock buttons -->
  <% if locked? %>
    <button class="btn btn-warning" data-action="click->lock-control#showUnlockConfirmation">
      Unlock
    </button>
  <% else %>
    <button class="btn btn-primary" data-action="click->lock-control#lock">
      Lock
    </button>
  <% end %>
<% end %>
```

### 5. Add request_id to PrefabClient Logs ⚠️ MEDIUM
**Priority**: P2 (Nice to have)  
**Estimated Effort**: 1 hour  
**Test Required**: Log output verification test

Thread `request_id` through the entire call stack:
1. Generate in `PrefabControlService.set_characteristic`
2. Pass to `PrefabClient.update_characteristic(..., request_id: request_id)`
3. Log in `execute_curl_base` with `[request_id]` prefix
4. Store in `ControlEvent` (already done ✅)

---

## 📋 PRD-5-07 GARAGE DOOR SPECIFIC RISKS

### Why Garage Doors Are Higher Risk:
1. **Physical Damage**: Rapid open/close can damage motor, track, or sensors
2. **Obstruction Detection**: Must handle "obstructed" state (similar to jammed)
3. **Partial State**: Garage doors have "opening" and "closing" transient states
4. **Longer Operation Time**: 10-20 seconds (vs 1-2s for locks) → higher echo risk

### Additional Requirements for PRD-5-07:
1. **Obstruction State Handling**: Similar to jammed lock, but may auto-recover
2. **Progress Indication**: Show "Opening..." state during operation (10-20s)
3. **Echo Prevention Window**: Increase from 5s to 10s for garage doors
4. **Confirmation for BOTH Open and Close**: Unlike locks, closing a garage door is also a security-reducing action
5. **Obstruction Alert**: If `current_state == 4` (obstructed), show alert and disable controls

---

## 📊 FINAL SCORECARD

| Category | Score | Weight | Weighted Score |
|----------|-------|--------|----------------|
| **Security Compliance** | 3/10 | 40% | 1.2/4.0 |
| **Code Quality** | 6/10 | 25% | 1.5/2.5 |
| **Test Coverage** | 4/10 | 20% | 0.8/2.0 |
| **Maintainability** | 7/10 | 15% | 1.05/1.5 |
| **TOTAL** | **4.55/10** | | **45.5%** |

### Letter Grade: C+
**Reasoning**:
- ✅ Strong UI/UX foundation (confirmation modal, offline detection, optimistic updates)
- ✅ Audit logging infrastructure in place
- ❌ Three critical security violations (Open3 misuse, no echo prevention, no timeout)
- ❌ Insufficient test coverage for control flow
- ❌ Jammed state not fully handled as terminal error

---

## 🎬 CONCLUSION

PRD-5-06 demonstrates a **solid understanding of UI best practices** but **critical gaps in backend security implementation**. The Open3 misuse alone is a **blocking issue** that prevents ANY lock control from working.

### For Immediate Action (Before Merge):
1. Fix Open3.capture3 misuse (15 minutes) ⚠️
2. Add integration tests for control flow (1 hour)

### For PRD-5-07 Readiness (Before Starting Garage Doors):
3. Implement webhook echo prevention (2 hours) ⚠️
4. Add Open3 timeout (30 minutes)
5. Fix jammed state UI logic (30 minutes)
6. Add request_id to PrefabClient logs (1 hour)

### Long-Term Improvements:
7. Add system tests with Capybara for lock UI
8. Implement frontend timeout for hanging API calls
9. Add Sentry/error tracking for Open3 failures

**Estimated Total Effort to Production-Ready**: 6-8 hours

---

## 📝 APPENDIX: COMPLIANCE CHECKLIST

| Requirement | Status | Evidence |
|-------------|--------|----------|
| **1. Security & Command Safety** |
| Use Open3.capture3 with timeouts | ❌ FAIL | Line 114: No timeout; Lines 118-119: Incorrect .read() calls |
| No backticks, %x{}, system, exec | ✅ PASS | Verified via grep |
| Escape user-controlled values | ✅ PASS | ERB::Util.url_encode used |
| **2. Audit & Traceability** |
| Generate unique request_id (UUID) | ✅ PASS | PrefabControlService:100 |
| Log source field | ✅ PASS | AccessoriesController:26 (source: 'web') |
| Log user IP (request.remote_ip) | ✅ PASS | AccessoriesController:24 |
| Include latency in audit | ✅ PASS | PrefabControlService:27 |
| Full error logging | ✅ PASS | PrefabControlService:31 |
| **3. Deduplication & Echo Prevention** |
| Check recent ControlEvent before webhook | ❌ FAIL | Not implemented |
| Dedupe window: 2-5 seconds | ❌ FAIL | Not implemented |
| Skip if matching recent control exists | ❌ FAIL | Not implemented |
| **4. Data Handling & Coercion** |
| Boolean coercion for truthy/falsy | ✅ PASS | AccessoriesController:48-59 (general), :73 (Lock specific) |
| Validate and coerce before save/send | ✅ PASS | AccessoriesController:30 |
| **5. Retry & Resilience** |
| Exactly 3 attempts | ✅ PASS | PrefabControlService:15-18 |
| 500ms fixed sleep | ✅ PASS | RETRY_DELAY = 0.5 |
| Log full error on final failure | ✅ PASS | PrefabControlService:31 |
| Set success=false in audit | ✅ PASS | PrefabControlService:100 |
| **6. Testing Mandate** |
| Unit tests for public methods | ⚠️ PARTIAL | Component tested, service not tested |
| Integration tests with WebMock | ❌ FAIL | No controller integration tests |
| Cover retries and failures | ❌ FAIL | No failure scenario tests |
| Cover deduplication logic | ❌ FAIL | Deduplication not implemented |
| Cover Open3 error cases | ❌ FAIL | Open3 not tested |

**Overall Epic 5 Compliance**: **52%** (11/21 requirements met)

---

**END OF REPORT**

Generated by: Principal Architect Review System  
Next Review Milestone: PRD-5-07 (Garage Door Controls) - Pre-Implementation  
Approved for: Limited Production (Lock Controls Only) - WITH MANDATORY FIXES
