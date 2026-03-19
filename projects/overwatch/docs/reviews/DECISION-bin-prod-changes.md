# DECISION: bin/prod Changes

**Date:** 2026-02-23  
**Decision:** ✅ Implement Modified Option A  
**Reject:** ❌ Option B (Foreman approach)

---

## What to Implement ✅

### 1. Add rbenv Initialization (CRITICAL)
**Line:** After line 21  
**Priority:** 🔴 HIGH

```bash
if [ -f ~/.zprofile ]; then source ~/.zprofile; fi
if command -v rbenv >/dev/null 2>&1; then eval "$(rbenv init -)"; fi
echo -e "${BLUE}Ruby Version:${NC} $(ruby -v)"
```

### 2. Add PATH Validation (RECOMMENDED)
**Line:** Before database checks  
**Priority:** 🟡 MEDIUM

```bash
if ! command -v psql >/dev/null 2>&1; then
    echo -e "${RED}✗ psql not found${NC}" >&2
    exit 1
fi
```

### 3. Fix Database Check (ACCURACY)
**Line:** 60  
**Priority:** 🟡 MEDIUM

```bash
# Change from:
psql -U nextgen_plaid -d postgres

# To:
psql -U nextgen_plaid -d nextgen_plaid_production
```

---

## What NOT to Implement ❌

### ❌ Do NOT Add Foreman/Procfile.prod

**Reason:** Production uses launchd, not Foreman

**Instead:**
- Keep bin/prod single-purpose (web server only)
- Use launchd plist for process supervision
- Create separate launchd services for workers

---

## Quick Implementation

```bash
# 1. Update bin/prod with 3 changes above
# 2. Test locally
./bin/prod

# 3. Deploy
git add bin/prod
git commit -m "Fix bin/prod: rbenv init, PATH validation, DB check"
git push origin main

# 4. Pull on production
ssh ericsmith66@192.168.4.253
cd ~/Development/nextgen-plaid
git pull origin main
./bin/prod  # Test
```

---

## Files Created

1. **bin-prod-recommendation-review.md** - Full technical review (12K words)
2. **bin-prod-improved.sh** - Complete implementation
3. **bin-prod-recommendation-executive-summary.md** - Executive summary
4. **bin-prod-comparison.md** - Side-by-side comparison
5. **DECISION-bin-prod-changes.md** - This decision document

---

## Rationale

| Change | Why Implement | Why NOT Foreman |
|--------|---------------|-----------------|
| rbenv | Ensures correct Ruby version | Production needs launchd supervision |
| PATH | Better error messages | Single point of failure with Foreman |
| Database | Accuracy | Conflicts with existing architecture |

---

**Estimated Time:** 1 hour  
**Risk Level:** LOW  
**Confidence:** HIGH (95%)

**Approved by:** DevOps Engineering  
**Review Complete:** ✅
