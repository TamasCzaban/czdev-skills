# Vertical Profiles for Pulse-Check Rotation

Each pulse run picks the next vertical in `vertical_rotation` from `analytics/pulse/.state.json`. Sub-Agent A (Vertical Pain Scout) targets only that vertical. Do not mention no-code tools in vertical searches — look for operational pain first, then connect back to tooling in the angle.

---

## 1. logistics

**ICP fit:** Rental companies, freight brokers, 3PLs, last-mile delivery ops running 5–50 people. Heavy relational data (routes, assets, contracts). BEMER CRM is direct proof.

**Search templates:**
- `site:reddit.com (r/logistics OR r/Entrepreneur) "spreadsheet hell" OR "manual dispatch" OR "can't track" 2025 OR 2026`
- `site:news.ycombinator.com logistics OR dispatch OR "route planning" "internal tool" OR "built our own" 2025 OR 2026`
- `logistics founder "Airtable" OR "Monday.com" OR "spreadsheet" frustration OR "doesn't scale" 2025 OR 2026`

**Pain signals:** route replanning chaos, driver comms fragmentation, invoice reconciliation, contract renewal tracking, asset utilization gaps.

---

## 2. agencies

**ICP fit:** Marketing, creative, dev, consulting agencies. Project/retainer tracking, timesheet hell, client reporting. Ops teams stitching HubSpot + Asana + Airtable + Slack.

**Search templates:**
- `site:reddit.com (r/agency OR r/consulting) "time tracking" OR "client reporting" OR "project management" broken OR nightmare 2025 OR 2026`
- `site:news.ycombinator.com agency "internal tool" OR "built for ourselves" OR "process breaks" 2025 OR 2026`
- `agency owner "scope creep" OR "utilization" OR "margin erosion" spreadsheet OR Airtable 2025 OR 2026`

**Pain signals:** utilization reporting, retainer burndown tracking, proposal-to-invoice sprawl, context switching across 8 tools.

---

## 3. field-service

**ICP fit:** Trades, installers, maintenance, HVAC, cleaning, security services. Scheduling, work orders, technician dispatch, mobile data entry.

**Search templates:**
- `site:reddit.com (r/smallbusiness OR r/Entrepreneur) "field service" OR "work order" OR "technician scheduling" 2025 OR 2026`
- `site:news.ycombinator.com "dispatch" OR "field service" "Jobber" OR "ServiceTitan" alternative OR frustration 2025 OR 2026`
- `field service founder "can't scale" OR "manual scheduling" custom OR "built our own" 2025 OR 2026`

**Pain signals:** photo/signature capture on mobile, parts inventory sync, recurring maintenance contracts, dispatch gaming.

---

## 4. property

**ICP fit:** Property management, short-term rentals, co-living, student housing. Tenant communication, maintenance tickets, lease tracking, compliance.

**Search templates:**
- `site:reddit.com (r/realestateinvesting OR r/AirBnBHosts) "property management" "spreadsheet" OR "can't track" 2025 OR 2026`
- `site:news.ycombinator.com "property management" OR "short-term rental" "built" OR "tool" 2025 OR 2026`
- `property manager "maintenance tickets" OR "tenant portal" custom OR "outgrew" 2025 OR 2026`

**Pain signals:** maintenance escalation gaps, rent roll reconciliation, cleaner scheduling, multi-unit reporting.

---

## 5. ecommerce-ops

**ICP fit:** DTC brands, multi-channel sellers, subscription boxes. Order ops, returns, inventory, fulfillment. Shopify/Amazon + patchwork of Zaps.

**Search templates:**
- `site:reddit.com (r/ecommerce OR r/shopify) "order management" OR "inventory sync" OR "returns process" broken 2025 OR 2026`
- `site:news.ycombinator.com ecommerce "custom dashboard" OR "built for ops" 2025 OR 2026`
- `DTC founder "3PL" OR "inventory" OR "fulfillment" spreadsheet OR "manual" 2025 OR 2026`

**Pain signals:** oversell prevention, returns triage, multi-warehouse inventory, subscription churn triage, SKU proliferation.

---

## 6. manufacturing

**ICP fit:** Small-batch manufacturers, contract assemblers, metal/wood shops. BOM tracking, production scheduling, QC, vendor management.

**Search templates:**
- `site:reddit.com (r/manufacturing OR r/ArtisanGifts) "ERP" OR "production scheduling" OR "BOM" spreadsheet OR frustration 2025 OR 2026`
- `site:news.ycombinator.com manufacturing "custom ERP" OR "built our own" 2025 OR 2026`
- `manufacturing founder "shop floor" OR "production tracking" tool OR "we built" 2025 OR 2026`

**Pain signals:** shop-floor data entry, BOM revisions, vendor PO tracking, compliance docs, yield tracking.

---

## 7. healthcare-ops

**ICP fit:** Clinics, allied-health practices, therapy groups, telehealth back-office. Scheduling, intake, billing, compliance (GDPR, HIPAA).

**Search templates:**
- `site:reddit.com (r/medicine OR r/Entrepreneur) "clinic" OR "practice management" "spreadsheet" OR "outgrew" 2025 OR 2026`
- `site:news.ycombinator.com healthcare "internal tool" OR "compliance" OR "patient portal" founder 2025 OR 2026`
- `clinic owner "scheduling" OR "intake forms" OR "EHR" custom OR "built" 2025 OR 2026`

**Pain signals:** intake form hell, insurance eligibility checks, appointment reminders, compliance audit trails.

---

## 8. real-estate

**ICP fit:** Brokerages, buyer agents, commercial RE teams. Deal pipeline, commission splits, document chasing, market analysis.

**Search templates:**
- `site:reddit.com (r/realtors OR r/CommercialRealEstate) "pipeline" OR "CRM" OR "deal tracking" custom OR "outgrew" 2025 OR 2026`
- `site:news.ycombinator.com "real estate" "internal tool" OR "built" 2025 OR 2026`
- `broker "commission splits" OR "deal room" spreadsheet OR custom 2025 OR 2026`

**Pain signals:** commission calc disputes, document collection, MLS sync gaps, deal-stage reporting.

---

## How to select pain angles

For each signal returned, identify:
- **The lived moment** — a specific failure event (a renewal missed, a dispatch dropped, a compliance audit blown)
- **The tooling connection** — what are they using now and where it breaks
- **The CZ Dev angle** — a custom backend + database design that removes the ceiling (not a no-code pitch)
