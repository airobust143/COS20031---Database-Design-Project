// ============================================================
// Safety Ops Dashboard — live data from /api/safety.php
// Navigation structure:
//   - dashboard: Full overview with KPIs and tabs
//   - events: Safety Events only
//   - review: Review Queue only
//   - scores: Driver Scores only
//   - coaching: Coaching Records only
//   - suspend: Suspend/Reactivate only
// ============================================================

import { Safety } from '../api.ts';
import { icon, KPI_ICONS } from '../icons.ts';
import {
  severityBadge, reviewStatusBadge,
  driverStatusBadge, outcomeBadge, scoreClass,
} from '../utils.ts';

export async function renderSafetyOps(navId: string): Promise<string> {
  switch (navId) {
    case 'dashboard':
      return renderDashboard();
    case 'events':
      return renderEvents();
    case 'review':
      return renderReviewQueue();
    case 'scores':
      return renderScores();
    case 'coaching':
      return renderCoaching();
    case 'suspend':
      return renderSuspend();
    default:
      return renderDashboard();
  }
}

// ============================================================
// Dashboard — Full overview with KPIs and tabs
// ============================================================
async function renderDashboard(): Promise<string> {
  const [kpis, events, reviewQueue, scores, coaching, drivers, periods] = await Promise.all([
    Safety.kpis(),
    Safety.events(),
    Safety.reviewQueue(),
    Safety.scores(),
    Safety.coaching(),
    Safety.drivers(),
    Safety.lookupPeriods(),
  ]);

  const currentPeriod = periods[0]?.ScorePeriod ?? '';

  return `
<div class="kpi-grid">
  <div class="kpi-card">
    <div class="kpi-icon red">${KPI_ICONS.red}</div>
    <div class="kpi-value">${kpis.criticalThisMonth}</div>
    <div class="kpi-label">Critical Events (this month)</div>
    <div class="kpi-change down">Immediate review required</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon orange">${KPI_ICONS.orange}</div>
    <div class="kpi-value">${kpis.pendingReview}</div>
    <div class="kpi-label">Pending Reviews</div>
    <div class="kpi-change neutral">High &amp; Critical events</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon yellow">${KPI_ICONS.yellow}</div>
    <div class="kpi-value">${kpis.pendingCoaching}</div>
    <div class="kpi-label">Pending Coaching</div>
    <div class="kpi-change neutral">${kpis.driversFlagged} drivers flagged</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon red">${KPI_ICONS.red}</div>
    <div class="kpi-value">${kpis.suspendedDrivers}</div>
    <div class="kpi-label">Suspended Drivers</div>
    <div class="kpi-change down">Ineligible for assignment</div>
  </div>
</div>

${kpis.pendingReview > 0 ? `
<div class="alert-strip warn">
  ${icon('alert', 16)}
  <div><strong>${kpis.pendingReview} event(s) pending safety review.</strong>
  High and Critical incidents are auto-queued. Action them before driver re-assignment.</div>
</div>` : ''}

<div class="card">
  <div class="tab-list">
    <button class="tab-btn active" data-tab="stab-events">Safety Events</button>
    <button class="tab-btn" data-tab="stab-review">Review Queue${reviewQueue.length > 0 ? ` <span class="tab-count">${reviewQueue.length}</span>` : ''}</button>
    <button class="tab-btn" data-tab="stab-scores">Driver Scores</button>
    <button class="tab-btn" data-tab="stab-coaching">Coaching Records</button>
    <button class="tab-btn" data-tab="stab-suspend">Suspend / Reactivate</button>
  </div>

  <!-- Safety Events -->
  <div id="stab-events" class="tab-panel active">
    <div class="action-row" style="margin-bottom:16px">
      <div class="action-row-left">
        <input class="form-control" data-table-search="safety-events" placeholder="Search events…" style="width:200px">
        <select class="form-control" data-table-filter="safety-events" data-filter-column="4" style="width:140px">
          <option value="">All Severities</option>
          <option>Critical</option><option>High</option><option>Medium</option><option>Low</option>
        </select>
      </div>
      <div class="action-row-right">
        <button class="btn btn-primary btn-sm">${icon('plus',14)} Log Safety Event</button>
      </div>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Timestamp</th><th>Driver</th><th>Vehicle</th>
          <th>Event Type</th><th>Severity</th><th>Review Status</th><th>Actions</th>
        </tr></thead>
        <tbody data-table-body="safety-events">
          ${events.length === 0
            ? `<tr><td colspan="7"><div class="empty-state"><p>No safety events found.</p></div></td></tr>`
            : events.map(e => `
          <tr>
            <td class="text-muted">${e.Timestamp}</td>
            <td><strong>${e.DriverName}</strong></td>
            <td>${e.Vehicle}</td>
            <td>${e.EventType}</td>
            <td>${severityBadge(e.Severity as never)}</td>
            <td>${reviewStatusBadge(e.ReviewStatus)}</td>
            <td>
              <div class="flex gap-8">
                ${e.ReviewRequired && e.ReviewStatus === 'Pending'
                  ? `<button class="btn btn-warning btn-sm" data-action="review-start" data-id="${e.EventID}">Start Review</button>`
                  : ''}
                ${e.ReviewRequired && e.ReviewStatus === 'In Review'
                  ? `<button class="btn btn-primary btn-sm" data-action="review-complete" data-id="${e.EventID}">${icon('check',13)} Complete</button>`
                  : ''}
              </div>
            </td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>

  <!-- Review Queue -->
  <div id="stab-review" class="tab-panel">
    ${reviewQueue.length === 0
      ? `<div class="alert-strip success" style="margin:16px">${icon('check',16)}<div>No events pending review.</div></div>`
      : `<div class="alert-strip danger" style="margin-bottom:16px">
           ${icon('alert',16)}
           <div>Events below were auto-flagged because their severity is
           <strong>High</strong> or <strong>Critical</strong>.</div>
         </div>`}
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Timestamp</th><th>Driver</th><th>Event Type</th>
          <th>Severity</th><th>Status</th><th>Actions</th>
        </tr></thead>
        <tbody>
          ${reviewQueue.length === 0
            ? `<tr><td colspan="6"><div class="empty-state"><p>Queue is clear.</p></div></td></tr>`
            : reviewQueue.map(e => `
          <tr>
            <td class="text-muted">${e.Timestamp}</td>
            <td><strong>${e.DriverName}</strong></td>
            <td>${e.EventType}</td>
            <td>${severityBadge(e.Severity as never)}</td>
            <td>${reviewStatusBadge(e.ReviewStatus)}</td>
            <td>
              <div class="flex gap-8">
                ${e.ReviewStatus === 'Pending'
                  ? `<button class="btn btn-warning btn-sm" data-action="review-start" data-id="${e.EventID}">Start Review</button>`
                  : ''}
                ${e.ReviewStatus === 'In Review'
                  ? `<button class="btn btn-primary btn-sm" data-action="review-complete" data-id="${e.EventID}">${icon('check',13)} Complete</button>`
                  : ''}
              </div>
            </td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>

  <!-- Driver Scores -->
  <div id="stab-scores" class="tab-panel">
    <div class="action-row" style="margin-bottom:16px">
      <div class="action-row-left">
        <select class="form-control" style="width:150px">
          ${periods.map(p => `<option${p.ScorePeriod === currentPeriod ? ' selected' : ''}>${p.ScorePeriod}</option>`).join('')}
        </select>
      </div>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Driver</th><th>Score</th><th>Deducted</th>
          <th>Low</th><th>Med</th><th>High</th><th>Crit</th>
          <th>Coaching</th><th>Suspended</th>
        </tr></thead>
        <tbody>
          ${scores.length === 0
            ? `<tr><td colspan="9"><div class="empty-state"><p>No scores for this period.</p></div></td></tr>`
            : scores.map(s => `
          <tr>
            <td><strong>${s.DriverName}</strong></td>
            <td><div class="score-circle ${scoreClass(Number(s.FinalScore))}"
                     style="width:40px;height:40px;font-size:13px">${s.FinalScore}</div></td>
            <td class="text-muted">−${s.DeductedPoints}</td>
            <td><span class="badge badge-green">${s.LowCount}</span></td>
            <td><span class="badge badge-yellow">${s.MediumCount}</span></td>
            <td><span class="badge badge-orange">${s.HighCount}</span></td>
            <td><span class="badge badge-red">${s.CriticalCount}</span></td>
            <td>${Number(s.CoachingRequired) ? '<span class="badge badge-orange">Required</span>' : '<span class="badge badge-gray">No</span>'}</td>
            <td>${Number(s.Suspended) ? '<span class="badge badge-red">Yes</span>' : '<span class="badge badge-gray">No</span>'}</td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>

  <!-- Coaching Records -->
  <div id="stab-coaching" class="tab-panel">
    <div class="action-row" style="margin-bottom:16px">
      <div class="action-row-right">
        <button class="btn btn-primary btn-sm">${icon('plus',14)} New Coaching Record</button>
      </div>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Driver</th><th>Reason</th><th>Type</th>
          <th>Scheduled</th><th>Completed</th><th>Outcome</th>
        </tr></thead>
        <tbody>
          ${coaching.length === 0
            ? `<tr><td colspan="6"><div class="empty-state"><p>No coaching records.</p></div></td></tr>`
            : coaching.map(c => `
          <tr>
            <td><strong>${c.DriverName}</strong></td>
            <td>${c.Reason}</td>
            <td><span class="badge badge-purple">${c.RecordType}</span></td>
            <td>${c.ScheduledDate}</td>
            <td>${c.CompleteDate ?? '—'}</td>
            <td>${outcomeBadge(c.Outcome)}</td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>

  <!-- Suspend / Reactivate -->
  <div id="stab-suspend" class="tab-panel">
    <div class="alert-strip info" style="margin-bottom:16px">
      ${icon('shield',16)}
      <div>Suspending sets <code>EmploymentStatus = 'Suspended'</code> and
      blocks vehicle assignments until reactivated.</div>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Driver</th><th>Depot</th><th>Safety Score</th><th>Status</th><th>Action</th>
        </tr></thead>
        <tbody>
          ${drivers.map(d => `
          <tr>
            <td><strong>${d.DriverName}</strong></td>
            <td>${d.DepotName}</td>
            <td>
              <div class="score-circle ${scoreClass(Number(d.SafetyScore))}"
                   style="width:36px;height:36px;font-size:12px;border-width:2px">
                ${d.SafetyScore}
              </div>
            </td>
            <td>${driverStatusBadge(d.EmploymentStatus as never)}</td>
            <td>
              ${d.EmploymentStatus === 'Suspended' || d.EmploymentStatus === 'Inactive'
                ? `<button class="btn btn-primary btn-sm" data-action="reactivate-driver" data-id="${d.DriverID}">${icon('check',13)} Reactivate</button>`
                : `<button class="btn btn-danger btn-sm" data-action="suspend-driver" data-id="${d.DriverID}">${icon('suspend',13)} Suspend</button>`}
            </td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>
</div>`;
}


// ============================================================
// Safety Events Page — Events only
// ============================================================
async function renderEvents(): Promise<string> {
  const events = await Safety.events();

  return `
<div class="card">
  <div class="card-header">
    <div>
      <h2>Safety Events</h2>
      <p>All recorded safety incidents</p>
    </div>
    <button class="btn btn-primary btn-sm">${icon('plus',14)} Log Safety Event</button>
  </div>
  <div class="card-body">
    <div class="action-row" style="margin-bottom:16px">
      <div class="action-row-left">
        <input class="form-control" data-table-search="safety-events" placeholder="Search events…" style="width:200px">
        <select class="form-control" data-table-filter="safety-events" data-filter-column="4" style="width:140px">
          <option value="">All Severities</option>
          <option>Critical</option><option>High</option><option>Medium</option><option>Low</option>
        </select>
      </div>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Timestamp</th><th>Driver</th><th>Vehicle</th>
          <th>Event Type</th><th>Severity</th><th>Review Status</th><th>Actions</th>
        </tr></thead>
        <tbody data-table-body="safety-events">
          ${events.length === 0
            ? `<tr><td colspan="7"><div class="empty-state"><p>No safety events found.</p></div></td></tr>`
            : events.map(e => `
          <tr>
            <td class="text-muted">${e.Timestamp}</td>
            <td><strong>${e.DriverName}</strong></td>
            <td>${e.Vehicle}</td>
            <td>${e.EventType}</td>
            <td>${severityBadge(e.Severity as never)}</td>
            <td>${reviewStatusBadge(e.ReviewStatus)}</td>
            <td>
              <div class="flex gap-8">
                ${e.ReviewRequired && e.ReviewStatus === 'Pending'
                  ? `<button class="btn btn-warning btn-sm" data-action="review-start" data-id="${e.EventID}">Start Review</button>`
                  : ''}
                ${e.ReviewRequired && e.ReviewStatus === 'In Review'
                  ? `<button class="btn btn-primary btn-sm" data-action="review-complete" data-id="${e.EventID}">${icon('check',13)} Complete</button>`
                  : ''}
              </div>
            </td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>
</div>`;
}

// ============================================================
// Review Queue Page — Review only
// ============================================================
async function renderReviewQueue(): Promise<string> {
  const reviewQueue = await Safety.reviewQueue();

  return `
${reviewQueue.length === 0
  ? `<div class="alert-strip success">
      ${icon('check',16)}<div><strong>No events pending review.</strong>
      Queue is clear — all high and critical events have been reviewed.</div>
    </div>`
  : `<div class="alert-strip danger">
       ${icon('alert',16)}
       <div><strong>${reviewQueue.length} event(s) pending safety review.</strong>
       Events below were auto-flagged because their severity is <strong>High</strong> or <strong>Critical</strong>.</div>
     </div>`}

<div class="card">
  <div class="card-header">
    <div>
      <h2>Review Queue</h2>
      <p>High and critical events requiring review</p>
    </div>
  </div>
  <div class="card-body">
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Timestamp</th><th>Driver</th><th>Vehicle</th><th>Event Type</th>
          <th>Severity</th><th>Status</th><th>Actions</th>
        </tr></thead>
        <tbody>
          ${reviewQueue.length === 0
            ? `<tr><td colspan="7"><div class="empty-state">
                ${icon('check', 32)}
                <p><strong>Queue is clear</strong></p>
                <p class="text-muted">All events have been reviewed</p>
              </div></td></tr>`
            : reviewQueue.map(e => `
          <tr>
            <td class="text-muted">${e.Timestamp}</td>
            <td><strong>${e.DriverName}</strong></td>
            <td>${e.Vehicle}</td>
            <td>${e.EventType}</td>
            <td>${severityBadge(e.Severity as never)}</td>
            <td>${reviewStatusBadge(e.ReviewStatus)}</td>
            <td>
              <div class="flex gap-8">
                ${e.ReviewStatus === 'Pending'
                  ? `<button class="btn btn-warning btn-sm" data-action="review-start" data-id="${e.EventID}">Start Review</button>`
                  : ''}
                ${e.ReviewStatus === 'In Review'
                  ? `<button class="btn btn-primary btn-sm" data-action="review-complete" data-id="${e.EventID}">${icon('check',13)} Complete</button>`
                  : ''}
              </div>
            </td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>
</div>`;
}

// ============================================================
// Driver Scores Page — Scores only
// ============================================================
async function renderScores(): Promise<string> {
  const [scores, periods] = await Promise.all([
    Safety.scores(),
    Safety.lookupPeriods(),
  ]);

  const currentPeriod = periods[0]?.ScorePeriod ?? '';

  return `
<div class="card">
  <div class="card-header">
    <div>
      <h2>Driver Scores</h2>
      <p>Safety performance by period</p>
    </div>
  </div>
  <div class="card-body">
    <div class="action-row" style="margin-bottom:16px">
      <div class="action-row-left">
        <select class="form-control" style="width:150px">
          ${periods.map(p => `<option${p.ScorePeriod === currentPeriod ? ' selected' : ''}>${p.ScorePeriod}</option>`).join('')}
        </select>
      </div>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Driver</th><th>Score</th><th>Deducted</th>
          <th>Low</th><th>Med</th><th>High</th><th>Crit</th>
          <th>Coaching</th><th>Suspended</th>
        </tr></thead>
        <tbody>
          ${scores.length === 0
            ? `<tr><td colspan="9"><div class="empty-state"><p>No scores for this period.</p></div></td></tr>`
            : scores.map(s => `
          <tr>
            <td><strong>${s.DriverName}</strong></td>
            <td><div class="score-circle ${scoreClass(Number(s.FinalScore))}"
                     style="width:40px;height:40px;font-size:13px">${s.FinalScore}</div></td>
            <td class="text-muted">−${s.DeductedPoints}</td>
            <td><span class="badge badge-green">${s.LowCount}</span></td>
            <td><span class="badge badge-yellow">${s.MediumCount}</span></td>
            <td><span class="badge badge-orange">${s.HighCount}</span></td>
            <td><span class="badge badge-red">${s.CriticalCount}</span></td>
            <td>${Number(s.CoachingRequired) ? '<span class="badge badge-orange">Required</span>' : '<span class="badge badge-gray">No</span>'}</td>
            <td>${Number(s.Suspended) ? '<span class="badge badge-red">Yes</span>' : '<span class="badge badge-gray">No</span>'}</td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>
</div>`;
}

// ============================================================
// Coaching Records Page — Coaching only
// ============================================================
async function renderCoaching(): Promise<string> {
  const coaching = await Safety.coaching();

  return `
<div class="card">
  <div class="card-header">
    <div>
      <h2>Coaching Records</h2>
      <p>Driver coaching sessions and outcomes</p>
    </div>
    <button class="btn btn-primary btn-sm">${icon('plus',14)} New Coaching Record</button>
  </div>
  <div class="card-body">
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Driver</th><th>Reason</th><th>Type</th>
          <th>Scheduled</th><th>Completed</th><th>Outcome</th>
        </tr></thead>
        <tbody>
          ${coaching.length === 0
            ? `<tr><td colspan="6"><div class="empty-state"><p>No coaching records.</p></div></td></tr>`
            : coaching.map(c => `
          <tr>
            <td><strong>${c.DriverName}</strong></td>
            <td>${c.Reason}</td>
            <td><span class="badge badge-purple">${c.RecordType}</span></td>
            <td>${c.ScheduledDate}</td>
            <td>${c.CompleteDate ?? '—'}</td>
            <td>${outcomeBadge(c.Outcome)}</td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>
</div>`;
}

// ============================================================
// Suspend/Reactivate Page — Driver status management only
// ============================================================
async function renderSuspend(): Promise<string> {
  const drivers = await Safety.drivers();
  const suspendedCount = drivers.filter(d => d.EmploymentStatus === 'Suspended').length;

  return `
<div class="alert-strip info">
  ${icon('shield',16)}
  <div>Suspending sets <code>EmploymentStatus = 'Suspended'</code> and
  blocks vehicle assignments until reactivated. Currently <strong>${suspendedCount}</strong> driver(s) suspended.</div>
</div>

<div class="card">
  <div class="card-header">
    <div>
      <h2>Suspend / Reactivate Drivers</h2>
      <p>Manage driver employment status based on safety performance</p>
    </div>
  </div>
  <div class="card-body">
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Driver</th><th>Depot</th><th>Safety Score</th><th>Status</th><th>Action</th>
        </tr></thead>
        <tbody>
          ${drivers.map(d => `
          <tr>
            <td><strong>${d.DriverName}</strong></td>
            <td>${d.DepotName}</td>
            <td>
              <div class="score-circle ${scoreClass(Number(d.SafetyScore))}"
                   style="width:36px;height:36px;font-size:12px;border-width:2px">
                ${d.SafetyScore}
              </div>
            </td>
            <td>${driverStatusBadge(d.EmploymentStatus as never)}</td>
            <td>
              ${d.EmploymentStatus === 'Suspended' || d.EmploymentStatus === 'Inactive'
                ? `<button class="btn btn-primary btn-sm" data-action="reactivate-driver" data-id="${d.DriverID}">${icon('check',13)} Reactivate</button>`
                : `<button class="btn btn-danger btn-sm" data-action="suspend-driver" data-id="${d.DriverID}">${icon('suspend',13)} Suspend</button>`}
            </td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>
</div>`;
}
