// ============================================================
// Workshop Manager Dashboard — live data from /api/workshop.php
// Navigation structure:
//   - dashboard: Full overview with KPIs and tabs
//   - jobs: Job Board only
//   - alerts: Alerts Inbox only
//   - parts: Parts & Suppliers only
//   - warranty: Warranty Claims only
//   - roster: Mechanic Roster only
// ============================================================

import { Workshop } from '../api.ts';
import { icon, KPI_ICONS } from '../icons.ts';
import {
  jobStatusBadge, alertStatusBadge, severityBadge,
  warrantyStatusBadge, driverStatusBadge, fmtCurrency,
} from '../utils.ts';

export async function renderWorkshopManager(navId: string): Promise<string> {
  switch (navId) {
    case 'dashboard':
      return renderDashboard();
    case 'jobs':
      return renderJobs();
    case 'alerts':
      return renderAlerts();
    case 'parts':
      return renderParts();
    case 'warranty':
      return renderWarranty();
    case 'roster':
      return renderRoster();
    default:
      return renderDashboard();
  }
}

// ============================================================
// Dashboard — Full overview with KPIs and tabs
// ============================================================
async function renderDashboard(): Promise<string> {
  const [kpis, jobs, alerts, parts, suppliers, warranty, mechanics] = await Promise.all([
    Workshop.kpis(),
    Workshop.jobs(),
    Workshop.alerts(),
    Workshop.parts(),
    Workshop.suppliers(),
    Workshop.warranty(),
    Workshop.mechanics(),
  ]);

  const lowStockParts = parts.filter(p => Number(p.QuantityInStock) <= Number(p.ReorderThreshold));

  return `
<div class="kpi-grid">
  <div class="kpi-card">
    <div class="kpi-icon orange">${KPI_ICONS.orange}</div>
    <div class="kpi-value">${kpis.openJobs}</div>
    <div class="kpi-label">Open Jobs</div>
    <div class="kpi-change neutral">${kpis.inProgress} in progress</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon red">${KPI_ICONS.red}</div>
    <div class="kpi-value">${kpis.newAlerts}</div>
    <div class="kpi-label">New Alerts</div>
    <div class="kpi-change down">Action required</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon yellow">${KPI_ICONS.yellow}</div>
    <div class="kpi-value">${kpis.lowStock}</div>
    <div class="kpi-label">Low-Stock Parts</div>
    <div class="kpi-change down">Below reorder threshold</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon blue">${KPI_ICONS.blue}</div>
    <div class="kpi-value">${kpis.pendingClaims}</div>
    <div class="kpi-label">Pending Claims</div>
    <div class="kpi-change neutral">Warranty review queue</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon green">${KPI_ICONS.green}</div>
    <div class="kpi-value">${kpis.activeMechanics}</div>
    <div class="kpi-label">Active Mechanics</div>
    <div class="kpi-change up">Staffed &amp; ready</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon purple">${KPI_ICONS.purple}</div>
    <div class="kpi-value">${fmtCurrency(Number(kpis.totalCost))}</div>
    <div class="kpi-label">Total Job Costs</div>
    <div class="kpi-change neutral">All-time</div>
  </div>
</div>

${kpis.newAlerts > 0 ? `
<div class="alert-strip warn">
  ${icon('alert', 16)}
  <div><strong>${kpis.newAlerts} predictive alert(s) need attention.</strong>
  Acknowledge or create a job. Unacknowledged alerts escalate automatically.</div>
</div>` : ''}

<div class="card">
  <div class="tab-list">
    <button class="tab-btn active" data-tab="wtab-jobs">Job Board</button>
    <button class="tab-btn" data-tab="wtab-alerts">Alerts Inbox${kpis.newAlerts > 0 ? ` <span class="tab-count">${kpis.newAlerts}</span>` : ''}</button>
    <button class="tab-btn" data-tab="wtab-parts">Parts &amp; Suppliers</button>
    <button class="tab-btn" data-tab="wtab-warranty">Warranty Claims</button>
    <button class="tab-btn" data-tab="wtab-roster">Mechanic Roster</button>
  </div>

  <!-- Job Board -->
  <div id="wtab-jobs" class="tab-panel active">
    <div class="action-row" style="margin-bottom:16px">
      <div class="action-row-left">
        <input class="form-control" data-table-search="workshop-jobs" placeholder="Search jobs…" style="width:200px">
        <select class="form-control" data-table-filter="workshop-jobs" data-filter-column="5" style="width:150px">
          <option value="">All Statuses</option><option>Open</option>
          <option>In Progress</option><option>Closed</option>
        </select>
      </div>
      <div class="action-row-right">
        <button class="btn btn-primary btn-sm" data-action="create-workshop-job">${icon('plus',14)} New Job</button>
      </div>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Job ID</th><th>Vehicle</th><th>Workshop</th>
          <th>Opened</th><th>Closed</th><th>Status</th><th>Cost</th><th>Alert</th>
        </tr></thead>
        <tbody data-table-body="workshop-jobs">
          ${jobs.length === 0
            ? `<tr><td colspan="8"><div class="empty-state"><p>No jobs found.</p></div></td></tr>`
            : jobs.map(j => `
          <tr>
            <td><strong>JOB-${String(j.JobID).padStart(4,'0')}</strong></td>
            <td>${j.RegistrationNumber} — ${j.VehicleModel}</td>
            <td>${j.WorkshopName}</td>
            <td>${j.DateOpened.split(' ')[0]}</td>
            <td>${j.DateClosed ? j.DateClosed.split(' ')[0] : '—'}</td>
            <td>${jobStatusBadge(j.Status as never)}</td>
            <td>${fmtCurrency(Number(j.TotalCost))}</td>
            <td>${j.AlertID
              ? `<span class="badge badge-orange">ALT-${j.AlertID}</span>`
              : '<span class="text-muted">—</span>'}</td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>

  <!-- Alerts Inbox -->
  <div id="wtab-alerts" class="tab-panel">
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Alert ID</th><th>Vehicle</th><th>Alert Type</th>
          <th>Severity</th><th>Generated</th><th>Status</th><th>Actions</th>
        </tr></thead>
        <tbody>
          ${alerts.length === 0
            ? `<tr><td colspan="7"><div class="empty-state"><p>No alerts.</p></div></td></tr>`
            : alerts.map(a => `
          <tr>
            <td><strong>ALT-${a.AlertID}</strong></td>
            <td>${a.Vehicle}</td>
            <td>${a.AlertType}</td>
            <td>${severityBadge(a.Severity as never)}</td>
            <td class="text-muted">${a.GeneratedAt}</td>
            <td>${alertStatusBadge(a.Status as never)}</td>
            <td>
              <div class="flex gap-8">
                ${a.Status === 'New' ? `
                  <button class="btn btn-primary btn-sm" data-action="ack-alert" data-id="${a.AlertID}">${icon('check',13)} Acknowledge</button>
                  <button class="btn btn-warning btn-sm" data-action="create-workshop-job" data-id="${a.AlertID}">${icon('wrench',13)} Create Job</button>
                ` : a.Status === 'Acknowledged' ? `
                  <button class="btn btn-warning btn-sm" data-action="create-workshop-job" data-id="${a.AlertID}">${icon('wrench',13)} Create Job</button>
                  <button class="btn btn-danger btn-sm" data-action="escalate-alert" data-id="${a.AlertID}">${icon('alert',13)} Escalate</button>
                ` : a.Status === 'Scheduled' ? `
                  <button class="btn btn-primary btn-sm" data-action="resolve-alert" data-id="${a.AlertID}">${icon('check',13)} Resolve</button>
                ` : `<span class="text-muted">—</span>`}
              </div>
            </td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>

  <!-- Parts & Suppliers -->
  <div id="wtab-parts" class="tab-panel">
    ${lowStockParts.length > 0 ? `
    <div class="alert-strip warn" style="margin-bottom:16px">
      ${icon('box', 16)}
      <div><strong>${lowStockParts.length} part(s) below reorder threshold.</strong>
      Place orders to avoid maintenance delays.</div>
    </div>` : ''}
    <div class="two-col">
      <div>
        <div class="action-row" style="margin-bottom:12px">
          <span style="font-weight:600;font-size:14px">Parts Inventory</span>
          <button class="btn btn-primary btn-sm" data-action="create-workshop-part">${icon('plus',14)} Add Part</button>
        </div>
        <div class="table-wrap">
          <table>
            <thead><tr>
              <th>Part #</th><th>Description</th>
              <th>Stock</th><th>Threshold</th><th>Unit Price</th>
            </tr></thead>
            <tbody>
              ${parts.map(p => `
              <tr ${Number(p.QuantityInStock) <= Number(p.ReorderThreshold)
                    ? 'style="background:var(--orange-light)"' : ''}>
                <td><strong>${p.PartNumber}</strong></td>
                <td>${p.Description}</td>
                <td>${Number(p.QuantityInStock) <= Number(p.ReorderThreshold)
                  ? `<span class="badge badge-red">${icon('alert',11)} ${p.QuantityInStock}</span>`
                  : `<span class="badge badge-green">${p.QuantityInStock}</span>`}</td>
                <td class="text-muted">${p.ReorderThreshold}</td>
                <td>${fmtCurrency(Number(p.UnitPrice))}</td>
              </tr>`).join('')}
            </tbody>
          </table>
        </div>
      </div>
      <div>
        <div class="action-row" style="margin-bottom:12px">
          <span style="font-weight:600;font-size:14px">Suppliers</span>
          <button class="btn btn-primary btn-sm" data-action="create-workshop-supplier">${icon('plus',14)} Add Supplier</button>
        </div>
        <div class="table-wrap">
          <table>
            <thead><tr><th>Supplier</th><th>Contact</th><th>Lead Time</th></tr></thead>
            <tbody>
              ${suppliers.map(s => `
              <tr>
                <td><strong>${s.Name}</strong></td>
                <td class="text-muted">${s.ContactInfo ?? '—'}</td>
                <td><span class="badge badge-blue">${s.LeadTimeDays}d</span></td>
              </tr>`).join('')}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>

  <!-- Warranty Claims -->
  <div id="wtab-warranty" class="tab-panel">
    <div class="action-row" style="margin-bottom:16px">
      <div class="action-row-right">
        <button class="btn btn-primary btn-sm" data-action="create-warranty-claim">${icon('plus',14)} New Claim</button>
      </div>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Claim ID</th><th>Job</th><th>Activity</th>
          <th>Type</th><th>Claim Date</th><th>Status</th>
        </tr></thead>
        <tbody>
          ${warranty.length === 0
            ? `<tr><td colspan="6"><div class="empty-state"><p>No warranty claims.</p></div></td></tr>`
            : warranty.map(w => `
          <tr>
            <td><strong>CLM-${String(w.ClaimID).padStart(4,'0')}</strong></td>
            <td>${w.JobRef}</td>
            <td>ACT-${String(w.ActivityID).padStart(4,'0')}</td>
            <td><span class="badge badge-purple">${w.WarrantyType}</span></td>
            <td>${w.ClaimDate}</td>
            <td>${warrantyStatusBadge(w.Status)}</td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>

  <!-- Mechanic Roster -->
  <div id="wtab-roster" class="tab-panel">
    <div class="action-row" style="margin-bottom:16px">
      <div class="action-row-right">
        <button class="btn btn-primary btn-sm" data-action="create-workshop-mechanic">${icon('plus',14)} Add Mechanic</button>
      </div>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Name</th><th>Workshop</th><th>Certifications</th><th>Status</th>
        </tr></thead>
        <tbody>
          ${mechanics.map(m => `
          <tr>
            <td><strong>${m.FirstName} ${m.LastName}</strong></td>
            <td>${m.WorkshopName}</td>
            <td>${m.CertList.map(c =>
              `<span class="badge badge-blue" style="margin-right:4px">${c}</span>`
            ).join('') || '<span class="text-muted">None</span>'}</td>
            <td>${driverStatusBadge(m.EmploymentStatus as never)}</td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>
</div>`;
}


// ============================================================
// Job Board Page — Jobs only
// ============================================================
async function renderJobs(): Promise<string> {
  const jobs = await Workshop.jobs();

  return `
<div class="card">
  <div class="card-header">
    <div>
      <h2>Job Board</h2>
      <p>All maintenance jobs across workshops</p>
    </div>
  </div>
  <div class="card-body">
    <div class="action-row" style="margin-bottom:16px">
      <div class="action-row-left">
        <input class="form-control" data-table-search="workshop-jobs" placeholder="Search jobs…" style="width:200px">
        <select class="form-control" data-table-filter="workshop-jobs" data-filter-column="5" style="width:150px">
          <option value="">All Statuses</option><option>Open</option>
          <option>In Progress</option><option>Closed</option>
        </select>
      </div>
      <div class="action-row-right">
        <button class="btn btn-primary btn-sm" data-action="create-workshop-job">${icon('plus',14)} New Job</button>
      </div>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Job ID</th><th>Vehicle</th><th>Workshop</th>
          <th>Opened</th><th>Closed</th><th>Status</th><th>Cost</th><th>Alert</th>
        </tr></thead>
        <tbody data-table-body="workshop-jobs">
          ${jobs.length === 0
            ? `<tr><td colspan="8"><div class="empty-state"><p>No jobs found.</p></div></td></tr>`
            : jobs.map(j => `
          <tr>
            <td><strong>JOB-${String(j.JobID).padStart(4,'0')}</strong></td>
            <td>${j.RegistrationNumber} — ${j.VehicleModel}</td>
            <td>${j.WorkshopName}</td>
            <td>${j.DateOpened.split(' ')[0]}</td>
            <td>${j.DateClosed ? j.DateClosed.split(' ')[0] : '—'}</td>
            <td>${jobStatusBadge(j.Status as never)}</td>
            <td>${fmtCurrency(Number(j.TotalCost))}</td>
            <td>${j.AlertID
              ? `<span class="badge badge-orange">ALT-${j.AlertID}</span>`
              : '<span class="text-muted">—</span>'}</td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>
</div>`;
}

// ============================================================
// Alerts Inbox Page — Alerts only
// ============================================================
async function renderAlerts(): Promise<string> {
  const alerts = await Workshop.alerts();
  const newAlerts = alerts.filter(a => a.Status === 'New').length;

  return `
${newAlerts > 0 ? `
<div class="alert-strip warn">
  ${icon('alert', 16)}
  <div><strong>${newAlerts} predictive alert(s) need attention.</strong>
  Acknowledge or create a job. Unacknowledged alerts escalate automatically.</div>
</div>` : ''}

<div class="card">
  <div class="card-header">
    <div>
      <h2>Alerts Inbox</h2>
      <p>Predictive maintenance alerts requiring action</p>
    </div>
  </div>
  <div class="card-body">
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Alert ID</th><th>Vehicle</th><th>Alert Type</th>
          <th>Severity</th><th>Generated</th><th>Status</th><th>Actions</th>
        </tr></thead>
        <tbody>
          ${alerts.length === 0
            ? `<tr><td colspan="7"><div class="empty-state"><p>No alerts.</p></div></td></tr>`
            : alerts.map(a => `
          <tr>
            <td><strong>ALT-${a.AlertID}</strong></td>
            <td>${a.Vehicle}</td>
            <td>${a.AlertType}</td>
            <td>${severityBadge(a.Severity as never)}</td>
            <td class="text-muted">${a.GeneratedAt}</td>
            <td>${alertStatusBadge(a.Status as never)}</td>
            <td>
              <div class="flex gap-8">
                ${a.Status === 'New' ? `
                  <button class="btn btn-primary btn-sm" data-action="ack-alert" data-id="${a.AlertID}">${icon('check',13)} Acknowledge</button>
                  <button class="btn btn-warning btn-sm" data-action="create-workshop-job" data-id="${a.AlertID}">${icon('wrench',13)} Create Job</button>
                ` : a.Status === 'Acknowledged' ? `
                  <button class="btn btn-warning btn-sm" data-action="create-workshop-job" data-id="${a.AlertID}">${icon('wrench',13)} Create Job</button>
                  <button class="btn btn-danger btn-sm" data-action="escalate-alert" data-id="${a.AlertID}">${icon('alert',13)} Escalate</button>
                ` : a.Status === 'Scheduled' ? `
                  <button class="btn btn-primary btn-sm" data-action="resolve-alert" data-id="${a.AlertID}">${icon('check',13)} Resolve</button>
                ` : `<span class="text-muted">—</span>`}
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
// Parts & Suppliers Page — Parts only
// ============================================================
async function renderParts(): Promise<string> {
  const [parts, suppliers] = await Promise.all([
    Workshop.parts(),
    Workshop.suppliers(),
  ]);

  const lowStockParts = parts.filter(p => Number(p.QuantityInStock) <= Number(p.ReorderThreshold));

  return `
${lowStockParts.length > 0 ? `
<div class="alert-strip warn">
  ${icon('box', 16)}
  <div><strong>${lowStockParts.length} part(s) below reorder threshold.</strong>
  Place orders to avoid maintenance delays.</div>
</div>` : ''}

<div class="two-col">
  <div class="card">
    <div class="card-header">
      <div>
        <h2>Parts Inventory</h2>
        <p>Stock levels and pricing</p>
      </div>
      <button class="btn btn-primary btn-sm" data-action="create-workshop-part">${icon('plus',14)} Add Part</button>
    </div>
    <div class="card-body">
      <div class="table-wrap">
        <table>
          <thead><tr>
            <th>Part #</th><th>Description</th>
            <th>Stock</th><th>Threshold</th><th>Unit Price</th>
          </tr></thead>
          <tbody>
            ${parts.map(p => `
            <tr ${Number(p.QuantityInStock) <= Number(p.ReorderThreshold)
                  ? 'style="background:var(--orange-light)"' : ''}>
              <td><strong>${p.PartNumber}</strong></td>
              <td>${p.Description}</td>
              <td>${Number(p.QuantityInStock) <= Number(p.ReorderThreshold)
                ? `<span class="badge badge-red">${icon('alert',11)} ${p.QuantityInStock}</span>`
                : `<span class="badge badge-green">${p.QuantityInStock}</span>`}</td>
              <td class="text-muted">${p.ReorderThreshold}</td>
              <td>${fmtCurrency(Number(p.UnitPrice))}</td>
            </tr>`).join('')}
          </tbody>
        </table>
      </div>
    </div>
  </div>

  <div class="card">
    <div class="card-header">
      <div>
        <h2>Suppliers</h2>
        <p>Contact information and lead times</p>
      </div>
      <button class="btn btn-primary btn-sm" data-action="create-workshop-supplier">${icon('plus',14)} Add Supplier</button>
    </div>
    <div class="card-body">
      <div class="table-wrap">
        <table>
          <thead><tr><th>Supplier</th><th>Contact</th><th>Lead Time</th></tr></thead>
          <tbody>
            ${suppliers.map(s => `
            <tr>
              <td><strong>${s.Name}</strong></td>
              <td class="text-muted">${s.ContactInfo ?? '—'}</td>
              <td><span class="badge badge-blue">${s.LeadTimeDays}d</span></td>
            </tr>`).join('')}
          </tbody>
        </table>
      </div>
    </div>
  </div>
</div>`;
}

// ============================================================
// Warranty Claims Page — Warranty only
// ============================================================
async function renderWarranty(): Promise<string> {
  const warranty = await Workshop.warranty();

  return `
<div class="card">
  <div class="card-header">
    <div>
      <h2>Warranty Claims</h2>
      <p>Track warranty submissions and approvals</p>
    </div>
    <button class="btn btn-primary btn-sm" data-action="create-warranty-claim">${icon('plus',14)} New Claim</button>
  </div>
  <div class="card-body">
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Claim ID</th><th>Job</th><th>Activity</th>
          <th>Type</th><th>Claim Date</th><th>Status</th>
        </tr></thead>
        <tbody>
          ${warranty.length === 0
            ? `<tr><td colspan="6"><div class="empty-state"><p>No warranty claims.</p></div></td></tr>`
            : warranty.map(w => `
          <tr>
            <td><strong>CLM-${String(w.ClaimID).padStart(4,'0')}</strong></td>
            <td>${w.JobRef}</td>
            <td>ACT-${String(w.ActivityID).padStart(4,'0')}</td>
            <td><span class="badge badge-purple">${w.WarrantyType}</span></td>
            <td>${w.ClaimDate}</td>
            <td>${warrantyStatusBadge(w.Status)}</td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>
</div>`;
}

// ============================================================
// Mechanic Roster Page — Mechanics only
// ============================================================
async function renderRoster(): Promise<string> {
  const mechanics = await Workshop.mechanics();

  return `
<div class="card">
  <div class="card-header">
    <div>
      <h2>Mechanic Roster</h2>
      <p>Workshop staff and certifications</p>
    </div>
    <button class="btn btn-primary btn-sm" data-action="create-workshop-mechanic">${icon('plus',14)} Add Mechanic</button>
  </div>
  <div class="card-body">
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Name</th><th>Workshop</th><th>Certifications</th><th>Status</th>
        </tr></thead>
        <tbody>
          ${mechanics.map(m => `
          <tr>
            <td><strong>${m.FirstName} ${m.LastName}</strong></td>
            <td>${m.WorkshopName}</td>
            <td>${m.CertList.map(c =>
              `<span class="badge badge-blue" style="margin-right:4px">${c}</span>`
            ).join('') || '<span class="text-muted">None</span>'}</td>
            <td>${driverStatusBadge(m.EmploymentStatus as never)}</td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>
</div>`;
}
