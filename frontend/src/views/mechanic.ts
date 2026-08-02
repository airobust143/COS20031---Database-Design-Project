// ============================================================
// Mechanic Dashboard — live data from /api/mechanic.php
// Row-scoped: only own assigned activities
// ============================================================

import { Mechanic } from '../api.ts';
import { icon, KPI_ICONS } from '../icons.ts';

export async function renderMechanic(_navId: string): Promise<string> {
  const [kpis, activities] = await Promise.all([
    Mechanic.kpis(),
    Mechanic.myActivities(),
  ]);

  return `
<div class="kpi-grid" style="grid-template-columns:repeat(4,1fr)">
  <div class="kpi-card">
    <div class="kpi-icon blue">${KPI_ICONS.blue}</div>
    <div class="kpi-value">${kpis.total}</div>
    <div class="kpi-label">Assigned Activities</div>
    <div class="kpi-change neutral">My current workload</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon orange">${KPI_ICONS.orange}</div>
    <div class="kpi-value">${kpis.inProgress}</div>
    <div class="kpi-label">In Progress</div>
    <div class="kpi-change neutral">Started, not closed</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon green">${KPI_ICONS.green}</div>
    <div class="kpi-value">${kpis.completed}</div>
    <div class="kpi-label">Completed</div>
    <div class="kpi-change up">This period</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon yellow">${KPI_ICONS.yellow}</div>
    <div class="kpi-value">${Number(kpis.totalHours).toFixed(1)} h</div>
    <div class="kpi-label">Labour Hours Logged</div>
    <div class="kpi-change ${Number(kpis.repeatFaults) > 0 ? 'down' : 'neutral'}">
      ${kpis.repeatFaults} repeat fault(s)
    </div>
  </div>
</div>

${Number(kpis.repeatFaults) > 0 ? `
<div class="alert-strip warn">
  ${icon('alert',16)}
  <div><strong>${kpis.repeatFaults} activity marked as repeat fault.</strong>
  Set the flag when logging a recurring issue.</div>
</div>` : ''}

<div class="card">
  <div class="card-header">
    <div>
      <h2>My Activities</h2>
      <p>Only activities assigned to you — ${activities.length} record${activities.length === 1 ? '' : 's'}</p>
    </div>
  </div>
  <div class="table-wrap">
    <table>
      <thead><tr>
        <th>Job</th><th>Vehicle</th><th>Activity Type</th>
        <th>Started</th><th>Completed</th><th>Labour Hrs</th>
        <th>Repeat Fault</th><th>Diagnostic Result</th><th>Actions</th>
      </tr></thead>
      <tbody>
        ${activities.length === 0
          ? `<tr><td colspan="9"><div class="empty-state"><p>No activities assigned to you.</p></div></td></tr>`
          : activities.map(a => `
        <tr>
          <td><strong>JOB-${String(a.JobID).padStart(4,'0')}</strong></td>
          <td>${a.RegistrationNumber} <span class="text-muted text-xs">${a.VehicleModel}</span></td>
          <td><span class="badge badge-blue">${a.ActivityType}</span></td>
          <td class="text-muted">${a.StartedAt ?? '—'}</td>
          <td class="text-muted">${a.CompleteAt ?? '—'}</td>
          <td>${Number(a.LabourHours) > 0
              ? `<span style="font-weight:600">${a.LabourHours} h</span>`
              : `<span class="text-muted">Not logged</span>`}</td>
          <td>${Number(a.IsRepeatFault)
              ? '<span class="badge badge-red">Yes</span>'
              : '<span class="badge badge-gray">No</span>'}</td>
          <td>${a.DiagnosticResult
              ? `<span title="${a.DiagnosticResult}" style="max-width:150px;display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${a.DiagnosticResult}</span>`
              : '<span class="text-muted">—</span>'}</td>
          <td>
            <button class="btn btn-primary btn-sm"
                    onclick="document.getElementById('mechanic-log-form').scrollIntoView({behavior:'smooth'});document.getElementById('sel-activity').value='${a.ActivityID}'">
              ${icon('log',13)} Log
            </button>
          </td>
        </tr>`).join('')}
      </tbody>
    </table>
  </div>
</div>

<div class="card" id="mechanic-log-form">
  <div class="card-header">
    <div>
      <h2>${icon('log',16)} Log Activity Details</h2>
      <p>Update your own assigned activity — diagnostic result, labour hours, repeat fault flag</p>
    </div>
  </div>
  <div class="card-body">
    <div class="form-row cols-2">
      <div class="form-group">
        <label class="form-label">Activity</label>
        <select id="sel-activity" class="form-control">
          <option value="">— Select activity —</option>
          ${activities.map(a =>
            `<option value="${a.ActivityID}">ACT-${String(a.ActivityID).padStart(4,'0')} — ${a.ActivityType} (${a.RegistrationNumber})</option>`
          ).join('')}
        </select>
      </div>
      <div class="form-group">
        <label class="form-label">Labour Hours</label>
        <input id="inp-hours" type="number" class="form-control"
               placeholder="e.g. 2.5" min="0" step="0.25">
      </div>
    </div>
    <div class="form-row cols-2">
      <div class="form-group">
        <label class="form-label">Started At</label>
        <input id="inp-started" type="datetime-local" class="form-control">
      </div>
      <div class="form-group">
        <label class="form-label">Completed At</label>
        <input id="inp-complete" type="datetime-local" class="form-control">
      </div>
    </div>
    <div class="form-row">
      <div class="form-group">
        <label class="form-label">Diagnostic Result</label>
        <textarea id="inp-diag" class="form-control"
                  placeholder="Describe findings and recommended actions…"></textarea>
      </div>
    </div>
    <div class="form-row">
      <div class="form-group" style="flex-direction:row;align-items:center;gap:10px">
        <input type="checkbox" id="chk-repeat" style="width:16px;height:16px;accent-color:var(--accent)">
        <label for="chk-repeat" class="form-label" style="margin:0;cursor:pointer">
          Mark as <strong>Repeat Fault</strong>
        </label>
      </div>
    </div>
    <div id="mechanic-form-status" style="min-height:24px;margin-top:8px"></div>
    <div class="flex gap-8" style="justify-content:flex-end;margin-top:8px">
      <button class="btn btn-secondary" id="btn-clear-mech">Clear</button>
      <button class="btn btn-primary" id="btn-save-mech">${icon('check',14)} Save Activity</button>
    </div>
  </div>
</div>

<script type="module">
import { Mechanic } from '/src/api.ts';

document.getElementById('btn-save-mech')?.addEventListener('click', async () => {
  const actId   = Number(document.getElementById('sel-activity').value);
  const hours   = parseFloat(document.getElementById('inp-hours').value);
  const diag    = document.getElementById('inp-diag').value.trim();
  const repeat  = document.getElementById('chk-repeat').checked;
  const started = document.getElementById('inp-started').value || null;
  const complete= document.getElementById('inp-complete').value || null;
  const status  = document.getElementById('mechanic-form-status');

  if (!actId) {
    status.innerHTML = '<span class="badge badge-red">Select an activity first.</span>';
    return;
  }

  try {
    await Mechanic.updateActivity(actId, {
      DiagnosticResult: diag || null,
      IsRepeatFault: repeat,
      StartedAt: started,
      CompleteAt: complete,
    });
    if (!isNaN(hours) && hours >= 0) {
      await Mechanic.updateLabour(actId, hours);
    }
    status.innerHTML = '<span class="badge badge-green">✓ Saved successfully.</span>';
    setTimeout(() => location.reload(), 1200);
  } catch (err) {
    status.innerHTML = '<span class="badge badge-red">✗ ' + err.message + '</span>';
  }
});

document.getElementById('btn-clear-mech')?.addEventListener('click', () => {
  ['sel-activity','inp-hours','inp-started','inp-complete','inp-diag'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.value = '';
  });
  document.getElementById('chk-repeat').checked = false;
  document.getElementById('mechanic-form-status').innerHTML = '';
});
</script>`;
}
