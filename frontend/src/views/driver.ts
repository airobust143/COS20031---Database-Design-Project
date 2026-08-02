// ============================================================
// Driver Dashboard — live data from /api/driver.php
// Read-only, own data only
// Navigation structure:
//   - dashboard: Overview with everything
//   - my-score: My Safety Score details
//   - my-events: Events + score history
//   - my-certs: Certifications only
// ============================================================

import { Driver } from '../api.ts';
import { icon, KPI_ICONS } from '../icons.ts';
import { severityBadge, reviewStatusBadge, scoreClass } from '../utils.ts';

export async function renderDriver(navId: string): Promise<string> {
  const [kpis, events, scores, certs] = await Promise.all([
    Driver.kpis(),
    Driver.myEvents(),
    Driver.myScores(),
    Driver.myCertifications(),
  ]);

  switch (navId) {
    case 'dashboard':
      return renderDashboardTab(kpis, events, scores, certs);
    case 'my-score':
      return renderSafetyScoreTab(kpis);
    case 'my-events':
      return renderEventsTab(events, scores);
    case 'my-certs':
      return renderCertificationsTab(certs, kpis);
    default:
      return renderDashboardTab(kpis, events, scores, certs);
  }
}

// ============================================================
// TAB 1: Dashboard Overview
// ============================================================
function renderDashboardTab(kpis: any, events: any[], scores: any[], certs: any[]): string {
  return `
<div class="card" style="background:linear-gradient(135deg,var(--accent-xlight),var(--surface))">
  <div class="card-body" style="display:flex;align-items:center;gap:24px;flex-wrap:wrap">
    <div class="score-circle ${scoreClass(kpis.latestScore)}"
         style="width:68px;height:68px;font-size:20px;flex-shrink:0">
      ${kpis.latestScore}
    </div>
    <div>
      <div style="font-weight:700;font-size:17px">${kpis.name}</div>
      <div class="text-muted" style="font-size:13px;margin-top:2px">
        Driver · Licence ${kpis.licenceType} · Expires ${kpis.licenceExpiry}
      </div>
      <div style="margin-top:8px;display:flex;gap:8px;flex-wrap:wrap">
        <span class="badge badge-${scoreClass(kpis.latestScore) === 'good' ? 'green' : scoreClass(kpis.latestScore) === 'caution' ? 'yellow' : 'red'}">
          Safety Score: ${kpis.latestScore} / 100
        </span>
        ${kpis.suspended ? `<span class="badge badge-red">${icon('suspend',11)} Suspended</span>` : ''}
        ${!kpis.suspended && kpis.status !== 'Active'
          ? `<span class="badge badge-yellow">${kpis.status}</span>` : ''}
        ${kpis.coachingRequired && !kpis.suspended
          ? `<span class="badge badge-orange">Coaching Required</span>` : ''}
        ${kpis.expiringSoon > 0
          ? `<span class="badge badge-orange">${icon('alert',11)} ${kpis.expiringSoon} cert expiring soon</span>` : ''}
        ${kpis.expiredCerts > 0
          ? `<span class="badge badge-red">${icon('alert',11)} ${kpis.expiredCerts} cert expired</span>` : ''}
      </div>
    </div>
    ${kpis.suspended ? `
    <div class="alert-strip danger" style="margin-left:auto;max-width:340px">
      ${icon('alert',16)}
      <div style="font-size:12px"><strong>Your account is currently suspended.</strong>
      Complete the scheduled coaching session to be reactivated.</div>
    </div>` : ''}
  </div>
</div>

<div class="kpi-grid" style="grid-template-columns:repeat(3,1fr)">
  <div class="kpi-card">
    <div class="kpi-icon red">${KPI_ICONS.red}</div>
    <div class="kpi-value">${kpis.recentEvents}</div>
    <div class="kpi-label">Events (last 3 months)</div>
    <div class="kpi-change ${kpis.recentEvents > 0 ? 'down' : 'up'}">Personal record</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon ${scoreClass(kpis.latestScore) === 'good' ? 'green' : scoreClass(kpis.latestScore) === 'caution' ? 'yellow' : 'red'}">
      ${scoreClass(kpis.latestScore) === 'good' ? KPI_ICONS.green : scoreClass(kpis.latestScore) === 'caution' ? KPI_ICONS.yellow : KPI_ICONS.red}
    </div>
    <div class="kpi-value">${kpis.latestScore}</div>
    <div class="kpi-label">Latest Safety Score</div>
    <div class="kpi-change ${kpis.latestScore >= 76 ? 'up' : 'down'}">
      ${kpis.latestScore >= 76 ? 'Above threshold' : 'Below threshold'}
    </div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon blue">${KPI_ICONS.blue}</div>
    <div class="kpi-value">${certs.length}</div>
    <div class="kpi-label">Certifications</div>
    <div class="kpi-change ${kpis.expiredCerts > 0 ? 'down' : kpis.expiringSoon > 0 ? 'neutral' : 'up'}">
      ${kpis.expiredCerts > 0
        ? `${kpis.expiredCerts} expired`
        : kpis.expiringSoon > 0
        ? `${kpis.expiringSoon} expiring soon`
        : 'All valid'}
    </div>
  </div>
</div>

<div class="two-col">
  <div class="card">
    <div class="card-header">
      <div>
        <h2>Recent Safety Events</h2>
        <p>Last 5 safety events</p>
      </div>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Date/Time</th><th>Event Type</th><th>Severity</th><th>Review</th>
        </tr></thead>
        <tbody>
          ${events.length === 0
            ? `<tr><td colspan="4"><div class="empty-state"><p>No safety events on record.</p></div></td></tr>`
            : events.slice(0, 5).map(e => `
          <tr>
            <td class="text-muted">${e.Timestamp}</td>
            <td>${e.EventType}</td>
            <td>${severityBadge(e.Severity as never)}</td>
            <td>${reviewStatusBadge(e.ReviewStatus)}</td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
    ${events.length > 5 ? `<div class="card-footer text-muted" style="text-align:center;font-size:13px">
      View all events in the Events tab
    </div>` : ''}
  </div>

  <div class="card">
    <div class="card-header">
      <div>
        <h2>My Certifications</h2>
        <p>Current certification status</p>
      </div>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Certification</th><th>Expires</th><th>Status</th>
        </tr></thead>
        <tbody>
          ${certs.length === 0
            ? `<tr><td colspan="3"><div class="empty-state"><p>No certifications on record.</p></div></td></tr>`
            : certs.slice(0, 5).map(c => {
              let status: string; let badgeCls: string;
              if (!c.ExpireDate) {
                status = 'No Expiry'; badgeCls = 'badge-green';
              } else {
                const diff = (new Date(c.ExpireDate).getTime() - Date.now()) / 86400000;
                if (diff < 0) { status = 'Expired'; badgeCls = 'badge-red'; }
                else if (diff <= 60) { status = `Expires in ${Math.ceil(diff)}d`; badgeCls = 'badge-orange'; }
                else { status = 'Valid'; badgeCls = 'badge-green'; }
              }
              return `
          <tr>
            <td><strong>${c.CertType}</strong></td>
            <td>${c.ExpireDate ?? '—'}</td>
            <td><span class="badge ${badgeCls}">${status}</span></td>
          </tr>`;
            }).join('')}
        </tbody>
      </table>
    </div>
    ${certs.length > 5 ? `<div class="card-footer text-muted" style="text-align:center;font-size:13px">
      View all certifications in the Certifications tab
    </div>` : ''}
  </div>
</div>

<div class="card">
  <div class="card-header">
    <div>
      <h2>Safety Score Trend</h2>
      <p>Your safety performance over time</p>
    </div>
  </div>
  <div class="card-body">
    <div class="chart-area" style="margin-bottom:16px;height:120px">
      ${scores.length === 0
        ? '<div class="empty-state" style="flex:1"><p>No score history.</p></div>'
        : [...scores].reverse().slice(-6).map(s => `
      <div class="chart-bar"
           style="height:${s.FinalScore}%;background:${scoreClass(Number(s.FinalScore))==='good'?'var(--accent-light)':scoreClass(Number(s.FinalScore))==='caution'?'var(--yellow-light)':'var(--red-light)'}"
           title="${s.ScorePeriod}: ${s.FinalScore}">
      </div>`).join('')}
    </div>
    <div class="text-muted" style="text-align:center;font-size:13px">
      View detailed score history in the Events tab
    </div>
  </div>
</div>`;
}

// ============================================================
// TAB 2: My Safety Score
// ============================================================
function renderSafetyScoreTab(kpis: any): string {
  return `
<div class="card" style="background:linear-gradient(135deg,var(--accent-xlight),var(--surface))">
  <div class="card-body" style="text-align:center;padding:48px 24px">
    <div class="score-circle ${scoreClass(kpis.latestScore)}"
         style="width:140px;height:140px;font-size:48px;margin:0 auto 24px;box-shadow:0 8px 16px rgba(0,0,0,0.1)">
      ${kpis.latestScore}
    </div>
    <h2 style="font-size:24px;margin-bottom:8px">Your Safety Score</h2>
    <p class="text-muted" style="font-size:15px">
      ${kpis.latestScore >= 90 ? 'Excellent performance! Keep up the great work.'
        : kpis.latestScore >= 76 ? 'Good performance. Continue safe driving practices.'
        : kpis.latestScore >= 60 ? 'Caution: Your score is below the recommended threshold.'
        : 'Critical: Immediate improvement required.'}
    </p>
    <div style="margin-top:24px;display:flex;gap:12px;justify-content:center;flex-wrap:wrap">
      <span class="badge badge-${scoreClass(kpis.latestScore) === 'good' ? 'green' : scoreClass(kpis.latestScore) === 'caution' ? 'yellow' : 'red'}" style="font-size:14px;padding:8px 16px">
        ${kpis.latestScore} / 100
      </span>
      ${kpis.suspended ? `<span class="badge badge-red" style="font-size:14px;padding:8px 16px">${icon('suspend',13)} Account Suspended</span>` : ''}
      ${kpis.coachingRequired && !kpis.suspended ? `<span class="badge badge-orange" style="font-size:14px;padding:8px 16px">Coaching Required</span>` : ''}
    </div>
  </div>
</div>

${kpis.suspended ? `
<div class="alert-strip danger">
  ${icon('alert',16)}
  <div>
    <strong>Your driving privileges are currently suspended.</strong>
    <p style="margin-top:4px">You must complete the scheduled coaching session with Safety Operations before your account can be reactivated. Contact your supervisor for more information.</p>
  </div>
</div>` : ''}

${kpis.coachingRequired && !kpis.suspended ? `
<div class="alert-strip warning">
  ${icon('alert',16)}
  <div>
    <strong>Coaching session required.</strong>
    <p style="margin-top:4px">Your safety score has triggered a coaching requirement. Safety Operations will contact you to schedule a session to review safe driving practices.</p>
  </div>
</div>` : ''}

<div class="card">
  <div class="card-header">
    <div>
      <h2>Driver Profile</h2>
      <p>Personal information and status</p>
    </div>
  </div>
  <div class="card-body">
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:24px">
      <div>
        <div class="text-muted" style="font-size:13px;margin-bottom:4px">Full Name</div>
        <div style="font-weight:600">${kpis.name}</div>
      </div>
      <div>
        <div class="text-muted" style="font-size:13px;margin-bottom:4px">Employment Status</div>
        <div>
          <span class="badge badge-${kpis.suspended ? 'red' : kpis.status === 'Active' ? 'green' : 'yellow'}">
            ${kpis.status}
          </span>
        </div>
      </div>
      <div>
        <div class="text-muted" style="font-size:13px;margin-bottom:4px">Licence Type</div>
        <div style="font-weight:600">${kpis.licenceType}</div>
      </div>
      <div>
        <div class="text-muted" style="font-size:13px;margin-bottom:4px">Licence Expiry</div>
        <div style="font-weight:600">${kpis.licenceExpiry}</div>
      </div>
    </div>
  </div>
</div>

<div class="two-col">
  <div class="card">
    <div class="card-header">
      <div>
        <h2>Score Breakdown</h2>
        <p>How your score is calculated</p>
      </div>
    </div>
    <div class="card-body">
      <div style="padding:16px;background:var(--surface-dim);border-radius:8px;margin-bottom:16px">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px">
          <span style="font-size:14px;color:var(--text-muted)">Base Score</span>
          <span style="font-size:18px;font-weight:700">100</span>
        </div>
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px">
          <span style="font-size:14px;color:var(--text-muted)">Recent Events (last 3 months)</span>
          <span style="font-size:18px;font-weight:700;color:var(--red)">${kpis.recentEvents}</span>
        </div>
        <div style="border-top:2px solid var(--border);padding-top:12px;display:flex;justify-content:space-between;align-items:center">
          <span style="font-size:15px;font-weight:600">Final Score</span>
          <span style="font-size:24px;font-weight:700;color:${scoreClass(kpis.latestScore) === 'good' ? 'var(--accent)' : scoreClass(kpis.latestScore) === 'caution' ? 'var(--yellow)' : 'var(--red)'}">
            ${kpis.latestScore}
          </span>
        </div>
      </div>
      <div class="text-muted" style="font-size:13px;line-height:1.6">
        <p style="margin-bottom:8px"><strong>Scoring Thresholds:</strong></p>
        <ul style="margin:0;padding-left:20px">
          <li><span class="badge badge-green" style="font-size:11px">90-100</span> Excellent</li>
          <li><span class="badge badge-green" style="font-size:11px">76-89</span> Good</li>
          <li><span class="badge badge-yellow" style="font-size:11px">60-75</span> Caution</li>
          <li><span class="badge badge-red" style="font-size:11px">0-59</span> Critical</li>
        </ul>
      </div>
    </div>
  </div>

  <div class="card">
    <div class="card-header">
      <div>
        <h2>Certification Status</h2>
        <p>Overview of your certifications</p>
      </div>
    </div>
    <div class="card-body">
      <div style="display:grid;gap:16px">
        <div style="padding:16px;background:var(--surface-dim);border-radius:8px;display:flex;align-items:center;gap:16px">
          <div class="kpi-icon green" style="width:48px;height:48px">
            ${KPI_ICONS.green}
          </div>
          <div style="flex:1">
            <div style="font-size:13px;color:var(--text-muted);margin-bottom:4px">Valid Certifications</div>
            <div style="font-size:20px;font-weight:700">${kpis.expiredCerts === 0 && kpis.expiringSoon === 0 ? 'All Valid' : 'Some Issues'}</div>
          </div>
        </div>
        ${kpis.expiringSoon > 0 ? `
        <div style="padding:16px;background:var(--yellow-xlight);border-radius:8px;display:flex;align-items:center;gap:16px">
          <div style="width:48px;height:48px;display:flex;align-items:center;justify-content:center">
            ${icon('alert', 24)}
          </div>
          <div style="flex:1">
            <div style="font-size:13px;color:var(--text-muted);margin-bottom:4px">Expiring Soon</div>
            <div style="font-size:20px;font-weight:700;color:var(--yellow)">${kpis.expiringSoon} certification${kpis.expiringSoon > 1 ? 's' : ''}</div>
          </div>
        </div>` : ''}
        ${kpis.expiredCerts > 0 ? `
        <div style="padding:16px;background:var(--red-xlight);border-radius:8px;display:flex;align-items:center;gap:16px">
          <div style="width:48px;height:48px;display:flex;align-items:center;justify-content:center">
            ${icon('alert', 24)}
          </div>
          <div style="flex:1">
            <div style="font-size:13px;color:var(--text-muted);margin-bottom:4px">Expired</div>
            <div style="font-size:20px;font-weight:700;color:var(--red)">${kpis.expiredCerts} certification${kpis.expiredCerts > 1 ? 's' : ''}</div>
          </div>
        </div>` : ''}
      </div>
      <div class="text-muted" style="font-size:13px;margin-top:16px;text-align:center">
        View all certifications in the Certifications tab
      </div>
    </div>
  </div>
</div>`;
}

// ============================================================
// TAB 3: Events (Safety Events + Score History)
// ============================================================
function renderEventsTab(events: any[], scores: any[]): string {
  return `
<div class="card">
  <div class="card-header">
    <div>
      <h2>My Safety Events</h2>
      <p>Complete history of safety incidents — read-only, contact Safety Ops for corrections</p>
    </div>
  </div>
  <div class="table-wrap">
    <table>
      <thead><tr>
        <th>Date/Time</th><th>Event Type</th><th>Severity</th><th>Vehicle</th><th>Review Status</th>
      </tr></thead>
      <tbody>
        ${events.length === 0
          ? `<tr><td colspan="5"><div class="empty-state">
              ${icon('check', 32)}
              <p><strong>No safety events on record</strong></p>
              <p class="text-muted">Great job! You have a clean safety record.</p>
            </div></td></tr>`
          : events.map(e => `
        <tr>
          <td class="text-muted">${e.Timestamp}</td>
          <td><strong>${e.EventType}</strong></td>
          <td>${severityBadge(e.Severity as never)}</td>
          <td>${e.Vehicle}</td>
          <td>${reviewStatusBadge(e.ReviewStatus)}</td>
        </tr>`).join('')}
      </tbody>
    </table>
  </div>
  ${events.length > 0 ? `<div class="card-footer text-muted" style="font-size:13px">
    Showing all ${events.length} safety event${events.length > 1 ? 's' : ''} on record
  </div>` : ''}
</div>

<div class="card">
  <div class="card-header">
    <div>
      <h2>Safety Score History</h2>
      <p>Monthly performance tracking — read-only personal record</p>
    </div>
  </div>
  <div class="card-body">
    <div class="chart-area" style="margin-bottom:24px;height:140px">
      ${scores.length === 0
        ? '<div class="empty-state" style="flex:1"><p>No score history available.</p></div>'
        : [...scores].reverse().map(s => `
      <div class="chart-bar"
           style="height:${s.FinalScore}%;background:${scoreClass(Number(s.FinalScore))==='good'?'var(--accent-light)':scoreClass(Number(s.FinalScore))==='caution'?'var(--yellow-light)':'var(--red-light)'}"
           title="${s.ScorePeriod}: ${s.FinalScore}">
        <span style="font-size:10px;color:var(--text-dim);position:absolute;top:-18px;left:50%;transform:translateX(-50%);white-space:nowrap">
          ${s.ScorePeriod.split('-')[1]}
        </span>
      </div>`).join('')}
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Period</th><th>Score</th><th>Low Events</th><th>Medium Events</th><th>High Events</th><th>Critical Events</th>
        </tr></thead>
        <tbody>
          ${scores.length === 0
            ? `<tr><td colspan="6"><div class="empty-state"><p>No score history available.</p></div></td></tr>`
            : scores.map(s => `
          <tr>
            <td><strong>${s.ScorePeriod}</strong></td>
            <td>
              <div class="score-circle ${scoreClass(Number(s.FinalScore))}"
                   style="width:42px;height:42px;font-size:14px;border-width:2px">
                ${s.FinalScore}
              </div>
            </td>
            <td><span class="badge badge-green">${s.LowCount}</span></td>
            <td><span class="badge badge-yellow">${s.MediumCount}</span></td>
            <td><span class="badge badge-orange">${s.HighCount}</span></td>
            <td><span class="badge badge-red">${s.CriticalCount}</span></td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>
  ${scores.length > 0 ? `<div class="card-footer text-muted" style="font-size:13px">
    Showing ${scores.length} period${scores.length > 1 ? 's' : ''} of score history
  </div>` : ''}
</div>`;
}

// ============================================================
// TAB 4: Certifications (Certs Only)
// ============================================================
function renderCertificationsTab(certs: any[], kpis: any): string {
  return `
${kpis.expiredCerts > 0 ? `
<div class="alert-strip danger">
  ${icon('alert',16)}
  <div>
    <strong>You have ${kpis.expiredCerts} expired certification${kpis.expiredCerts > 1 ? 's' : ''}.</strong>
    <p style="margin-top:4px">Contact your depot manager immediately to schedule renewal. Expired certifications may affect your ability to operate certain vehicles.</p>
  </div>
</div>` : ''}

${kpis.expiringSoon > 0 && kpis.expiredCerts === 0 ? `
<div class="alert-strip warning">
  ${icon('alert',16)}
  <div>
    <strong>You have ${kpis.expiringSoon} certification${kpis.expiringSoon > 1 ? 's' : ''} expiring soon.</strong>
    <p style="margin-top:4px">Contact your depot manager to schedule renewal before expiration to maintain uninterrupted driving privileges.</p>
  </div>
</div>` : ''}

<div class="card">
  <div class="card-header">
    <div>
      <h2>My Certifications</h2>
      <p>Complete list of driver certifications and training records</p>
    </div>
  </div>
  <div class="table-wrap">
    <table>
      <thead><tr>
        <th>Certification Type</th><th>Issue Date</th><th>Expiry Date</th><th>Status</th><th>Days Remaining</th>
      </tr></thead>
      <tbody>
        ${certs.length === 0
          ? `<tr><td colspan="5"><div class="empty-state">
              ${icon('certificate', 32)}
              <p><strong>No certifications on record</strong></p>
              <p class="text-muted">Contact your depot manager to add required certifications.</p>
            </div></td></tr>`
          : certs.map(c => {
              let status: string; let badgeCls: string; let daysRemaining: string;
              if (!c.ExpireDate) {
                status = 'No Expiry'; badgeCls = 'badge-green'; daysRemaining = '—';
              } else {
                const diff = (new Date(c.ExpireDate).getTime() - Date.now()) / 86400000;
                if (diff < 0) {
                  status = 'Expired'; badgeCls = 'badge-red';
                  daysRemaining = `${Math.abs(Math.ceil(diff))} days ago`;
                } else if (diff <= 30) {
                  status = 'Expiring Soon'; badgeCls = 'badge-red';
                  daysRemaining = `${Math.ceil(diff)} days`;
                } else if (diff <= 60) {
                  status = 'Renewal Due'; badgeCls = 'badge-orange';
                  daysRemaining = `${Math.ceil(diff)} days`;
                } else {
                  status = 'Valid'; badgeCls = 'badge-green';
                  daysRemaining = `${Math.ceil(diff)} days`;
                }
              }
              return `
        <tr>
          <td><strong>${c.CertType}</strong></td>
          <td>${c.IssueDate}</td>
          <td>${c.ExpireDate ?? '—'}</td>
          <td><span class="badge ${badgeCls}">${status}</span></td>
          <td class="text-muted">${daysRemaining}</td>
        </tr>`;
            }).join('')}
      </tbody>
    </table>
  </div>
  ${certs.length > 0 ? `<div class="card-footer text-muted" style="font-size:13px">
    Total: ${certs.length} certification${certs.length > 1 ? 's' : ''} on record
  </div>` : ''}
</div>

<div class="card">
  <div class="card-header">
    <div>
      <h2>Certification Information</h2>
      <p>Important details about maintaining your certifications</p>
    </div>
  </div>
  <div class="card-body">
    <div style="display:grid;gap:16px">
      <div style="padding:16px;background:var(--surface-dim);border-radius:8px">
        <h3 style="font-size:14px;font-weight:600;margin-bottom:8px">${icon('info', 16)} Renewal Process</h3>
        <p style="font-size:13px;color:var(--text-muted);line-height:1.6">
          Contact your depot manager at least 30 days before expiration to schedule certification renewal training. 
          Most certifications require a refresher course and exam.
        </p>
      </div>
      <div style="padding:16px;background:var(--surface-dim);border-radius:8px">
        <h3 style="font-size:14px;font-weight:600;margin-bottom:8px">${icon('alert', 16)} Expiration Policy</h3>
        <p style="font-size:13px;color:var(--text-muted);line-height:1.6">
          You cannot operate vehicles requiring expired certifications. Driving with expired certifications may result in 
          suspension and disciplinary action.
        </p>
      </div>
      <div style="padding:16px;background:var(--surface-dim);border-radius:8px">
        <h3 style="font-size:14px;font-weight:600;margin-bottom:8px">${icon('help', 16)} Need Help?</h3>
        <p style="font-size:13px;color:var(--text-muted);line-height:1.6">
          If you have questions about certification requirements or scheduling, contact your depot manager or 
          the Fleet Administration office.
        </p>
      </div>
    </div>
  </div>
</div>`;
}
