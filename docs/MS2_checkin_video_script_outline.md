# Milestone 2 Check-In Video Script Outline

Prepared for the Dizzy's Disease capstone Milestone 2 check-in. Follow the structure below during recording to satisfy rubric expectations and explicitly trace progress against the approved proposal timeline.

## 0. Pre-Recording Checklist
- Confirm the Godot Web build and FastAPI backend are running with fresh data.
- Capture proposal timeline slides highlighting Milestone 2 scope (`Inventory`, `Marketplace`, `Safe Zones`, `Deployment`, `Hostile Zone` kickoff).
- Export database snapshots or `psql` query output to illustrate hashed passwords and updated schema tables.
- Collect GitHub commit log covering the full Milestone 2 window.

## 1. Intro & Agenda (00:00–00:45)
- **Visuals**: Title slide listing agenda: Proposal Alignment → Demo → Architecture/Testing → Defects → Next Milestones.
- **Voiceover cues**:
  - Reconfirm switch from Unity to Godot and how scope was preserved.
  - Mention that you will reference the delivery plan throughout to address instructor feedback about alignment.

## 2. Alignment to Proposal Plan (00:45–02:30)
- **Visuals**: Proposal timeline screenshot with Milestone 2 tasks highlighted; overlay checkmarks for completed items and arrows for shifted items.
- **Voiceover cues**:
  - Inventory weight limits, marketplace buy/sell/filter, safe zone mechanics, deployment progress, and hostile-zone kickoff are on track per plan.
  - Call out the early delivery of market UI in Milestone 1 and explain compensating adjustments (e.g., moved additional backend work into MS2).
  - Promise explicit reporting of remaining MS2 items that roll to MS3 and how that recovers points.

## 3. Demonstration Part A – Authentication & Accounts (02:30–05:30)
- **Visuals**: Split-screen of FastAPI code (`hash_password` utility) and database viewer showing hashed credentials.
- **Demo beats**:
  1. Create a new user, then display the `users` table to prove the hashed + salted password value.
  2. Walk through password reset flow and show verification logic.
  3. Showcase character creation/selection UI rebuilt in Godot; point out data persisted via PostgreSQL tables introduced this milestone.
- **Voiceover cues**:
  - Emphasize backend security (hashing algorithm, no plain-text storage).
  - Tie character selection delivery to both the proposal and the Milestone 1 feedback list.

## 4. Demonstration Part B – Inventory, Market, Safe Zones (05:30–08:30)
- **Visuals**: Live gameplay capture in the Outpost scene.
- **Demo beats**:
  1. Equip/unequip items until the weight limit blocks an action; show UI feedback and DB update.
  2. Use market buy/sell, then apply type filter to highlight MS2 deliverables.
  3. Step between safe and hostile boundaries to prove combat gating and vendor-only zones.
- **Voiceover cues**:
  - Reference the exact proposal rows for inventory expansion and marketplace functionality.
  - Mention that inventory/market data is synchronized with the updated schema.

## 5. Demonstration Part C – Hostile Zone Kickoff (08:30–10:00)
- **Visuals**: Gameplay from the hostile zone scene.
- **Demo beats**:
  1. Trigger scavenging interaction that logs loot pull and DB write.
  2. Highlight the new melee zombie archetype and explain upcoming aggro system slated for Milestone 3.
- **Voiceover cues**:
  - Clarify which hostile-zone deliverables are complete now and which carry into next milestone (explicitly stating future milestone targets for partial credit recovery).

## 6. Architecture & Testing Evidence (10:00–11:30)
- **Visuals**: Project tree, ERD snippet, and terminal output from automated tests or API calls.
- **Content**:
  - Explain Godot architecture (autoload singletons, offline-first design) and how it satisfies the proposal structure.
  - Show test summary: unit/integration scripts, manual regression checklist, and sample API test.
- **Voiceover cues**:
  - Acknowledge any testing gaps and state scheduled remediation (e.g., additional coverage targeted for MS3).

## 7. Defects & Remediation Plan (11:30–12:30)
- **Visuals**: Defect tracker or markdown table listing issue, impact, owner, mitigation date.
- **Voiceover cues**:
  - Discuss outstanding items (level transitions, status-effect polish, automation scripts) and how they are scheduled.
  - Address prior feedback about incomplete remediation follow-up by pointing to current ownership and due dates.

## 8. GitHub Usage & Timeline Proof (12:30–13:30)
- **Visuals**: Git log filtered for the milestone period, with commit messages mapped to features shown.
- **Voiceover cues**:
  - Emphasize continuous commits and branches.
  - Mention repository URL and invite reviewers to inspect commits for evidence.

## 9. Closing & Next Milestones (13:30–14:30)
- **Visuals**: Slide summarizing completed MS2 deliverables, upcoming MS2 cleanup, and MS3 headline goals.
- **Voiceover cues**:
  - Reiterate how MS2 results align with the plan.
  - Specify which MS3 tasks start early (aggro system, dynamic pricing) to regain any lost points.
  - Conclude with contact details and readiness for the next check-in.

## Appendix – Evidence to Capture in Advance
- Annotated proposal timeline graphic showing shifts.
- Database ERD highlighting new tables (`Item`, `Inventory`, `Zone`, `NPC`).
- Test command transcript (`pytest`, `godot --headless --run-tests`, or manual checklist).
- Defect tracking sheet with remediation statuses.
- Git log export (`git log --since="2025-09-23" --until="2025-10-20" --oneline`).

