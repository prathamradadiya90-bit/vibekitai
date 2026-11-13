/**
 * High-performance, lightweight Vanilla HTML/CSS/JS Admin Dashboard SPA
 * Zero external node dependencies, mobile-responsive, dark/light mode, inline SVG charts.
 */
export function getAdminHtml(): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="robots" content="noindex, nofollow">
  <title>VibeKit AI - Admin Console</title>
  <style>
    :root {
      --bg-primary: #0a0e17;
      --bg-secondary: #121826;
      --bg-card: #182234;
      --border: #26354d;
      --text-main: #f1f5f9;
      --text-muted: #94a3b8;
      --accent: #6366f1;
      --accent-hover: #4f46e5;
      --success: #10b981;
      --warning: #f59e0b;
      --danger: #ef4444;
      --radius: 10px;
      --font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
    }

    [data-theme="light"] {
      --bg-primary: #f8fafc;
      --bg-secondary: #ffffff;
      --bg-card: #f1f5f9;
      --border: #cbd5e1;
      --text-main: #0f172a;
      --text-muted: #64748b;
      --accent: #4f46e5;
      --accent-hover: #4338ca;
    }

    * { box-sizing: border-box; margin: 0; padding: 0; font-family: var(--font-family); }
    body { background-color: var(--bg-primary); color: var(--text-main); min-height: 100vh; display: flex; flex-direction: column; }
    
    header {
      background-color: var(--bg-secondary);
      border-bottom: 1px solid var(--border);
      padding: 1rem 1.5rem;
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-wrap: wrap;
      gap: 1rem;
    }

    .brand { display: flex; align-items: center; gap: 0.75rem; font-weight: 700; font-size: 1.25rem; letter-spacing: -0.5px; }
    .badge-pro { background: linear-gradient(135deg, #6366f1, #ec4899); color: white; padding: 2px 8px; border-radius: 999px; font-size: 0.75rem; font-weight: 600; }
    .badge-role { background: rgba(99, 102, 241, 0.15); color: #818cf8; border: 1px solid rgba(99, 102, 241, 0.3); padding: 3px 10px; border-radius: 6px; font-size: 0.8rem; font-weight: 600; }
    
    .nav-tabs {
      display: flex;
      gap: 0.5rem;
      padding: 0.75rem 1.5rem;
      background: var(--bg-secondary);
      border-bottom: 1px solid var(--border);
      overflow-x: auto;
      white-space: nowrap;
    }

    .nav-btn {
      background: transparent;
      border: none;
      color: var(--text-muted);
      padding: 0.5rem 1rem;
      border-radius: var(--radius);
      cursor: pointer;
      font-size: 0.9rem;
      font-weight: 500;
      transition: all 0.2s ease;
    }

    .nav-btn:hover { color: var(--text-main); background: rgba(255, 255, 255, 0.05); }
    .nav-btn.active { color: white; background: var(--accent); }

    main { flex: 1; padding: 1.5rem; max-width: 1400px; width: 100%; margin: 0 auto; }
    .tab-content { display: none; }
    .tab-content.active { display: block; }

    .grid-kpis {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 1rem;
      margin-bottom: 1.5rem;
    }

    .kpi-card {
      background: var(--bg-secondary);
      border: 1px solid var(--border);
      border-radius: var(--radius);
      padding: 1.25rem;
      display: flex;
      flex-direction: column;
      gap: 0.5rem;
    }

    .kpi-title { font-size: 0.85rem; color: var(--text-muted); font-weight: 500; }
    .kpi-val { font-size: 1.85rem; font-weight: 700; color: var(--text-main); }
    .kpi-sub { font-size: 0.8rem; color: var(--text-muted); display: flex; align-items: center; gap: 4px; }
    .text-success { color: var(--success); }
    .text-warning { color: var(--warning); }
    .text-danger { color: var(--danger); }

    .card {
      background: var(--bg-secondary);
      border: 1px solid var(--border);
      border-radius: var(--radius);
      padding: 1.25rem;
      margin-bottom: 1.5rem;
    }

    .card-title { font-size: 1.1rem; font-weight: 600; margin-bottom: 1rem; display: flex; justify-content: space-between; align-items: center; }

    table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
    th { text-align: left; padding: 0.75rem; border-bottom: 2px solid var(--border); color: var(--text-muted); font-weight: 600; font-size: 0.8rem; text-transform: uppercase; }
    td { padding: 0.75rem; border-bottom: 1px solid var(--border); }
    tr:hover td { background: rgba(255, 255, 255, 0.02); }

    .table-container { overflow-x: auto; }

    .btn {
      background: var(--accent);
      color: white;
      border: none;
      padding: 0.5rem 1rem;
      border-radius: 6px;
      font-size: 0.85rem;
      font-weight: 600;
      cursor: pointer;
      transition: background 0.2s;
    }
    .btn:hover { background: var(--accent-hover); }
    .btn-secondary { background: var(--bg-card); color: var(--text-main); border: 1px solid var(--border); }
    .btn-secondary:hover { background: var(--border); }
    .btn-danger { background: var(--danger); color: white; }
    .btn-sm { padding: 0.25rem 0.6rem; font-size: 0.8rem; }

    .input-field {
      background: var(--bg-card);
      border: 1px solid var(--border);
      color: var(--text-main);
      padding: 0.5rem 0.75rem;
      border-radius: 6px;
      font-size: 0.9rem;
      outline: none;
    }
    .input-field:focus { border-color: var(--accent); }

    .badge-status {
      display: inline-block;
      padding: 2px 8px;
      border-radius: 999px;
      font-size: 0.75rem;
      font-weight: 600;
    }
    .status-active { background: rgba(16, 185, 129, 0.15); color: var(--success); }
    .status-banned { background: rgba(239, 68, 68, 0.15); color: var(--danger); }
    .status-expired { background: rgba(245, 158, 11, 0.15); color: var(--warning); }

    /* Modal Dialog */
    .modal-overlay {
      display: none;
      position: fixed;
      inset: 0;
      background: rgba(0, 0, 0, 0.7);
      backdrop-filter: blur(4px);
      z-index: 1000;
      align-items: center;
      justify-content: center;
    }
    .modal-overlay.active { display: flex; }
    .modal-box {
      background: var(--bg-secondary);
      border: 1px solid var(--border);
      border-radius: var(--radius);
      width: 90%;
      max-width: 500px;
      padding: 1.5rem;
      display: flex;
      flex-direction: column;
      gap: 1rem;
    }

    .form-group { display: flex; flex-direction: column; gap: 0.4rem; }
    .form-label { font-size: 0.85rem; color: var(--text-muted); font-weight: 500; }

    /* SVG Chart */
    .chart-svg { width: 100%; height: 200px; }
  </style>
</head>
<body>
  <header>
    <div class="brand">
      <span>✨ VibeKit AI</span>
      <span class="badge-pro">Admin</span>
      <span id="userRoleBadge" class="badge-role">authenticating...</span>
    </div>
    <div style="display: flex; align-items: center; gap: 0.75rem;">
      <span id="userEmailText" style="font-size: 0.85rem; color: var(--text-muted);"></span>
      <button class="btn btn-secondary btn-sm" onclick="toggleTheme()">🌓 Theme</button>
      <button class="btn btn-secondary btn-sm" onclick="promptToken()">🔑 Key</button>
      <button class="btn btn-sm" onclick="refreshCurrentTab()">🔄 Refresh</button>
    </div>
  </header>

  <nav class="nav-tabs">
    <button class="nav-btn active" onclick="switchTab('dashboard')">📊 Dashboard</button>
    <button class="nav-btn" onclick="switchTab('installations')">📱 Installations</button>
    <button class="nav-btn" onclick="switchTab('subscriptions')">💳 Subscriptions</button>
    <button class="nav-btn" onclick="switchTab('config')">⚙️ Remote Config</button>
    <button class="nav-btn" onclick="switchTab('ai_health')">🤖 AI Health</button>
    <button class="nav-btn" onclick="switchTab('feedback')">📬 Feedback</button>
    <button class="nav-btn" onclick="switchTab('abuse')">🛡️ Abuse Monitor</button>
    <button class="nav-btn" onclick="switchTab('audit_log')">📜 Audit Log</button>
  </nav>

  <main>
    <!-- TAB 1: DASHBOARD -->
    <div id="tab-dashboard" class="tab-content active">
      <div class="grid-kpis">
        <div class="kpi-card">
          <div class="kpi-title">Active Users (DAU / WAU / MAU)</div>
          <div id="kpiDau" class="kpi-val">-</div>
          <div id="kpiWauMau" class="kpi-sub">- WAU / - MAU</div>
        </div>
        <div class="kpi-card">
          <div class="kpi-title">Generations Today</div>
          <div id="kpiGenerations" class="kpi-val">-</div>
          <div id="kpiSuccessRate" class="kpi-sub text-success">- % Success</div>
        </div>
        <div class="kpi-card">
          <div class="kpi-title">Latency (Avg / p95)</div>
          <div id="kpiLatency" class="kpi-val">- ms</div>
          <div id="kpiP95" class="kpi-sub">- ms p95</div>
        </div>
        <div class="kpi-card">
          <div class="kpi-title">Est. Revenue (Sub + Ads)</div>
          <div id="kpiRevenue" class="kpi-val">₹ -</div>
          <div id="kpiAdRewards" class="kpi-sub">- Rewarded Ads</div>
        </div>
      </div>

      <div class="card">
        <div class="card-title">
          <span>Daily Generations & Activity Trend</span>
          <button class="btn btn-secondary btn-sm" onclick="triggerDailyAggregate()">Recalculate Stats</button>
        </div>
        <div id="trendChartContainer">
          <svg id="trendChartSvg" class="chart-svg" viewBox="0 0 800 200"></svg>
        </div>
      </div>

      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 1rem;">
        <div class="card">
          <div class="card-title">Streak Distribution</div>
          <div id="streakDistribution" style="display: flex; flex-direction: column; gap: 0.5rem;"></div>
        </div>
        <div class="card">
          <div class="card-title">Generations by Category</div>
          <div id="categoryBreakdown" style="display: flex; flex-direction: column; gap: 0.5rem;"></div>
        </div>
      </div>
    </div>

    <!-- TAB 2: INSTALLATIONS -->
    <div id="tab-installations" class="tab-content">
      <div class="card">
        <div class="card-title">
          <span>Search & Manage Installations</span>
          <div style="display: flex; gap: 0.5rem;">
            <input type="text" id="installSearchInput" class="input-field" placeholder="Search installation ID..." style="width: 250px;">
            <button class="btn btn-sm" onclick="loadInstallations()">Search</button>
          </div>
        </div>
        <div class="table-container">
          <table>
            <thead>
              <tr>
                <th>Installation ID</th>
                <th>Created</th>
                <th>Last Active</th>
                <th>Tier</th>
                <th>Credits Used</th>
                <th>Ads</th>
                <th>Streak</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody id="installationsTableBody">
              <tr><td colspan="9" style="text-align:center;">Loading installations...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- TAB 3: SUBSCRIPTIONS -->
    <div id="tab-subscriptions" class="tab-content">
      <div class="card">
        <div class="card-title">Subscription Entitlements</div>
        <div class="table-container">
          <table>
            <thead>
              <tr>
                <th>Installation ID</th>
                <th>Product ID</th>
                <th>Order ID</th>
                <th>Status</th>
                <th>Verified At</th>
                <th>Expires At</th>
              </tr>
            </thead>
            <tbody id="subscriptionsTableBody">
              <tr><td colspan="6" style="text-align:center;">Loading subscriptions...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- TAB 4: REMOTE CONFIG -->
    <div id="tab-config" class="tab-content">
      <div class="card">
        <div class="card-title">
          <span>Live Feature Flags & Limits</span>
          <button class="btn btn-sm" onclick="saveRemoteConfig()">Save Changes</button>
        </div>
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1rem;">
          <div class="form-group">
            <label class="form-label">Daily Free Credits</label>
            <input type="number" id="cfgFreeCredits" class="input-field" value="3">
          </div>
          <div class="form-group">
            <label class="form-label">Rewarded Credits Per Ad</label>
            <input type="number" id="cfgRewardCredits" class="input-field" value="3">
          </div>
          <div class="form-group">
            <label class="form-label">Max Daily Rewarded Ads</label>
            <input type="number" id="cfgMaxAds" class="input-field" value="2">
          </div>
          <div class="form-group">
            <label class="form-label">Paywall Variant</label>
            <select id="cfgPaywallVariant" class="input-field">
              <option value="default">Default</option>
              <option value="aggressive">Aggressive</option>
              <option value="soft">Soft Minimalist</option>
            </select>
          </div>
          <div class="form-group">
            <label class="form-label">Primary AI Provider</label>
            <select id="cfgAiProvider" class="input-field">
              <option value="gemini">Google Gemini 1.5</option>
              <option value="groq">Groq Llama 3</option>
              <option value="openrouter">OpenRouter Multi</option>
              <option value="openai">OpenAI GPT-4o-mini</option>
            </select>
          </div>
          <div class="form-group">
            <label class="form-label">Maintenance Mode</label>
            <select id="cfgMaintenanceMode" class="input-field">
              <option value="false">Operational (Off)</option>
              <option value="true">Active Maintenance (On)</option>
            </select>
          </div>
        </div>
      </div>

      <div class="card">
        <div class="card-title">Config Version History & Rollback</div>
        <div class="table-container">
          <table>
            <thead>
              <tr>
                <th>Version</th>
                <th>Updated By</th>
                <th>Timestamp</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody id="configHistoryTableBody">
              <tr><td colspan="4" style="text-align:center;">Loading config history...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- TAB 5: AI HEALTH -->
    <div id="tab-ai_health" class="tab-content">
      <div class="card">
        <div class="card-title">AI Provider Telemetry & Fallbacks</div>
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 1rem;">
          <div class="kpi-card">
            <div class="kpi-title">Primary Provider</div>
            <div id="aiPrimary" class="kpi-val" style="font-size: 1.3rem;">-</div>
          </div>
          <div class="kpi-card">
            <div class="kpi-title">Fallback Provider</div>
            <div id="aiFallback" class="kpi-val" style="font-size: 1.3rem;">-</div>
          </div>
          <div class="kpi-card">
            <div class="kpi-title">Success Rate</div>
            <div id="aiSuccessRate" class="kpi-val text-success">- %</div>
          </div>
          <div class="kpi-card">
            <div class="kpi-title">Average Latency</div>
            <div id="aiAvgLatency" class="kpi-val">- ms</div>
          </div>
        </div>
      </div>
    </div>

    <!-- TAB 6: FEEDBACK -->
    <div id="tab-feedback" class="tab-content">
      <div class="card">
        <div class="card-title">User Feedback Inbox</div>
        <div class="table-container">
          <table>
            <thead>
              <tr>
                <th>Created</th>
                <th>Installation</th>
                <th>Message</th>
                <th>Status</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody id="feedbackTableBody">
              <tr><td colspan="5" style="text-align:center;">Loading feedback...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- TAB 7: ABUSE MONITOR -->
    <div id="tab-abuse" class="tab-content">
      <div class="card">
        <div class="card-title">Rate Limiting & Abuse Signals</div>
        <div class="table-container">
          <table>
            <thead>
              <tr>
                <th>Anonymized IP Hash</th>
                <th>Request Count</th>
                <th>Window Start</th>
                <th>Last Update</th>
              </tr>
            </thead>
            <tbody id="abuseTableBody">
              <tr><td colspan="4" style="text-align:center;">Loading abuse signals...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- TAB 8: AUDIT LOG -->
    <div id="tab-audit_log" class="tab-content">
      <div class="card">
        <div class="card-title">Append-Only Admin Audit Log</div>
        <div class="table-container">
          <table>
            <thead>
              <tr>
                <th>Timestamp</th>
                <th>Admin Email</th>
                <th>Action</th>
                <th>Target ID</th>
                <th>Details</th>
              </tr>
            </thead>
            <tbody id="auditLogTableBody">
              <tr><td colspan="5" style="text-align:center;">Loading audit log...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </main>

  <!-- ACTION MODAL -->
  <div id="actionModal" class="modal-overlay">
    <div class="modal-box">
      <h3 id="modalTitle">Action</h3>
      <div id="modalBody"></div>
      <div style="display: flex; justify-content: flex-end; gap: 0.5rem; margin-top: 1rem;">
        <button class="btn btn-secondary" onclick="closeModal()">Cancel</button>
        <button id="modalConfirmBtn" class="btn">Confirm</button>
      </div>
    </div>
  </div>

  <script>
    let activeTab = 'dashboard';
    let adminToken = localStorage.getItem('vibekit_admin_token') || '';
    let currentRole = 'viewer';

    function getHeaders(isMutating = false) {
      const h = { 'Accept': 'application/json' };
      if (adminToken) h['Authorization'] = 'Bearer ' + adminToken;
      if (isMutating) {
        h['Content-Type'] = 'application/json';
        h['X-Admin-Action'] = '1';
      }
      return h;
    }

    async function apiFetch(url, options = {}) {
      try {
        const isMutating = ['POST', 'PUT', 'DELETE', 'PATCH'].includes((options.method || 'GET').toUpperCase());
        options.headers = { ...getHeaders(isMutating), ...(options.headers || {}) };
        const res = await fetch(url, options);
        if (res.status === 401) {
          promptToken('Authentication required. Enter Admin Secret or Token:');
          return null;
        }
        if (res.status === 403) {
          alert('Permission Denied: Your role does not have authorization for this operation.');
          return null;
        }
        return await res.json();
      } catch (e) {
        console.error('API Error:', e);
        return null;
      }
    }

    function promptToken(msg = 'Enter Admin Token or Secret:') {
      const val = prompt(msg, adminToken);
      if (val !== null) {
        adminToken = val.trim();
        localStorage.setItem('vibekit_admin_token', adminToken);
        init();
      }
    }

    function toggleTheme() {
      const current = document.documentElement.getAttribute('data-theme') || 'dark';
      const next = current === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', next);
    }

    function switchTab(tabId) {
      activeTab = tabId;
      document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
      const activeBtn = Array.from(document.querySelectorAll('.nav-btn')).find(b => b.getAttribute('onclick')?.includes(tabId));
      if (activeBtn) activeBtn.classList.add('active');
      const targetContent = document.getElementById('tab-' + tabId);
      if (targetContent) targetContent.classList.add('active');
      refreshCurrentTab();
    }

    function refreshCurrentTab() {
      if (activeTab === 'dashboard') loadDashboard();
      else if (activeTab === 'installations') loadInstallations();
      else if (activeTab === 'subscriptions') loadSubscriptions();
      else if (activeTab === 'config') loadConfig();
      else if (activeTab === 'ai_health') loadAiHealth();
      else if (activeTab === 'feedback') loadFeedback();
      else if (activeTab === 'abuse') loadAbuse();
      else if (activeTab === 'audit_log') loadAuditLog();
    }

    async function init() {
      const me = await apiFetch('/v1/admin/me');
      if (me) {
        currentRole = me.role;
        document.getElementById('userRoleBadge').textContent = me.role.toUpperCase();
        document.getElementById('userRoleBadge').style.borderColor = me.role === 'admin' ? '#10b981' : '#f59e0b';
        document.getElementById('userEmailText').textContent = me.email;
      }
      loadDashboard();
    }

    async function loadDashboard() {
      const data = await apiFetch('/v1/admin/dashboard');
      if (!data) return;

      document.getElementById('kpiDau').textContent = data.dau.toLocaleString();
      document.getElementById('kpiWauMau').textContent = data.wau + ' WAU / ' + data.mau + ' MAU';
      document.getElementById('kpiGenerations').textContent = data.generations.total.toLocaleString();
      
      const successPct = data.generations.total > 0 ? Math.round((data.generations.success / data.generations.total) * 100) : 100;
      document.getElementById('kpiSuccessRate').textContent = successPct + '% Success Rate';
      document.getElementById('kpiLatency').textContent = data.generations.avgLatencyMs + ' ms';
      document.getElementById('kpiP95').textContent = data.generations.p95LatencyMs + ' ms p95';
      document.getElementById('kpiRevenue').textContent = '₹ ' + data.totalEstimatedRevenueInr.toLocaleString();
      document.getElementById('kpiAdRewards').textContent = data.ads.rewardedGranted + ' Rewarded Ads Today';

      // Render Streak Distribution
      const streaks = data.streaks;
      document.getElementById('streakDistribution').innerHTML = \`
        <div>0 - 2 Days: <strong>\${streaks.range0_2}</strong></div>
        <div>3 - 6 Days: <strong>\${streaks.range3_6}</strong></div>
        <div>7 - 13 Days: <strong>\${streaks.range7_13}</strong></div>
        <div>14 - 29 Days: <strong>\${streaks.range14_29}</strong></div>
        <div>30+ Days: <strong>\${streaks.range30Plus}</strong></div>
      \`;

      // Render Categories
      const catHtml = Object.entries(data.generations.byCategory).map(([k, v]) =>
        \`<div>\${k.toUpperCase()}: <strong>\${v}</strong></div>\`
      ).join('');
      document.getElementById('categoryBreakdown').innerHTML = catHtml || '<div>No generations recorded today yet.</div>';

      // Render SVG Sparkline
      renderTrendSvg(data.dailyHistory || []);
    }

    function renderTrendSvg(history) {
      const svg = document.getElementById('trendChartSvg');
      if (!history || history.length === 0) {
        svg.innerHTML = '<text x="50%" y="50%" fill="#94a3b8" text-anchor="middle">No historical data available</text>';
        return;
      }
      const width = 800;
      const height = 180;
      const maxVal = Math.max(...history.map(h => h.generations), 10);
      const stepX = width / Math.max(history.length - 1, 1);

      let points = history.map((h, i) => {
        const x = i * stepX;
        const y = height - (h.generations / maxVal) * (height - 30) - 10;
        return \`\${x},\${y}\`;
      }).join(' ');

      svg.innerHTML = \`
        <polyline fill="none" stroke="#6366f1" stroke-width="3" points="\${points}" />
      \`;
    }

    async function triggerDailyAggregate() {
      const res = await apiFetch('/v1/admin/aggregate-daily', { method: 'POST', body: JSON.stringify({}) });
      if (res) {
        alert(res.message);
        loadDashboard();
      }
    }

    async function loadInstallations() {
      const search = document.getElementById('installSearchInput').value;
      const data = await apiFetch('/v1/admin/installations?search=' + encodeURIComponent(search));
      if (!data) return;

      const tbody = document.getElementById('installationsTableBody');
      if (!data.installations.length) {
        tbody.innerHTML = '<tr><td colspan="9" style="text-align:center;">No matching installations found.</td></tr>';
        return;
      }

      tbody.innerHTML = data.installations.map(i => \`
        <tr>
          <td><code>\${i.id.substring(0, 16)}...</code></td>
          <td>\${new Date(i.created_at).toLocaleDateString()}</td>
          <td>\${new Date(i.last_active_at).toLocaleDateString()}</td>
          <td>\${i.is_pro ? '<span class="badge-status status-active">PRO</span>' : '<span class="badge-status">Free</span>'}</td>
          <td>\${i.today_free_credits_used} / 3</td>
          <td>\${i.today_ads_watched}</td>
          <td>\${i.streak}d</td>
          <td>\${i.ban_reason ? '<span class="badge-status status-banned">Banned</span>' : '<span class="badge-status status-active">Active</span>'}</td>
          <td>
            <button class="btn btn-secondary btn-sm" onclick="showCreditModal('\${i.id}')">Credits</button>
            <button class="btn \${i.ban_reason ? 'btn-secondary' : 'btn-danger'} btn-sm" onclick="showBanModal('\${i.id}', \${Boolean(i.ban_reason)})">\${i.ban_reason ? 'Unban' : 'Ban'}</button>
          </td>
        </tr>
      \`).join('');
    }

    async function loadSubscriptions() {
      const data = await apiFetch('/v1/admin/subscriptions');
      if (!data) return;
      const tbody = document.getElementById('subscriptionsTableBody');
      if (!data.subscriptions.length) {
        tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;">No subscriptions found.</td></tr>';
        return;
      }
      tbody.innerHTML = data.subscriptions.map(s => \`
        <tr>
          <td><code>\${s.installation_id.substring(0, 16)}...</code></td>
          <td><strong>\${s.product_id}</strong></td>
          <td><code>\${s.order_id || 'N/A'}</code></td>
          <td><span class="badge-status \${s.status === 'ACTIVE' ? 'status-active' : 'status-expired'}">\${s.status}</span></td>
          <td>\${new Date(s.verified_at).toLocaleDateString()}</td>
          <td>\${s.expires_at ? new Date(s.expires_at).toLocaleDateString() : 'Lifetime / Active'}</td>
        </tr>
      \`).join('');
    }

    async function loadConfig() {
      const data = await apiFetch('/v1/admin/config');
      if (!data) return;
      if (data.current) {
        if (data.current.daily_free_credits) document.getElementById('cfgFreeCredits').value = data.current.daily_free_credits;
        if (data.current.reward_credits_per_ad) document.getElementById('cfgRewardCredits').value = data.current.reward_credits_per_ad;
        if (data.current.max_daily_rewards) document.getElementById('cfgMaxAds').value = data.current.max_daily_rewards;
        if (data.current.paywall_variant) document.getElementById('cfgPaywallVariant').value = data.current.paywall_variant;
        if (data.current.ai_provider) document.getElementById('cfgAiProvider').value = data.current.ai_provider;
      }

      const tbody = document.getElementById('configHistoryTableBody');
      tbody.innerHTML = (data.history || []).map(h => \`
        <tr>
          <td>v\${h.version}</td>
          <td>\${h.updated_by}</td>
          <td>\${new Date(h.created_at).toLocaleString()}</td>
          <td><button class="btn btn-secondary btn-sm" onclick="revertConfigVersion(\${h.version})">Revert</button></td>
        </tr>
      \`).join('');
    }

    async function saveRemoteConfig() {
      const payload = {
        configKey: 'app_remote_config',
        reason: 'Updated from Admin Console UI',
        values: {
          daily_free_credits: parseInt(document.getElementById('cfgFreeCredits').value, 10),
          reward_credits_per_ad: parseInt(document.getElementById('cfgRewardCredits').value, 10),
          max_daily_rewards: parseInt(document.getElementById('cfgMaxAds').value, 10),
          paywall_variant: document.getElementById('cfgPaywallVariant').value,
          ai_provider: document.getElementById('cfgAiProvider').value,
          maintenance_mode: document.getElementById('cfgMaintenanceMode').value === 'true',
        }
      };

      const res = await apiFetch('/v1/admin/config', { method: 'POST', body: JSON.stringify(payload) });
      if (res) {
        alert(res.message);
        loadConfig();
      }
    }

    async function revertConfigVersion(ver) {
      if (!confirm('Revert remote configuration to v' + ver + '?')) return;
      const res = await apiFetch('/v1/admin/config/revert', {
        method: 'POST',
        body: JSON.stringify({ configKey: 'app_remote_config', version: ver, reason: 'Reverted via UI' })
      });
      if (res) {
        alert(res.message);
        loadConfig();
      }
    }

    async function loadAiHealth() {
      const data = await apiFetch('/v1/admin/ai-health');
      if (!data) return;
      document.getElementById('aiPrimary').textContent = data.primaryProvider.toUpperCase();
      document.getElementById('aiFallback').textContent = data.fallbackProvider.toUpperCase();
      document.getElementById('aiSuccessRate').textContent = data.todayMetrics.successRatePct + ' %';
      document.getElementById('aiAvgLatency').textContent = data.todayMetrics.avgLatencyMs + ' ms';
    }

    async function loadFeedback() {
      const data = await apiFetch('/v1/admin/feedback');
      if (!data) return;
      const tbody = document.getElementById('feedbackTableBody');
      if (!data.feedback.length) {
        tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;">No feedback submitted.</td></tr>';
        return;
      }
      tbody.innerHTML = data.feedback.map(f => \`
        <tr>
          <td>\${new Date(f.created_at).toLocaleDateString()}</td>
          <td><code>\${(f.installation_id || 'anonymous').substring(0, 16)}...</code></td>
          <td>\${f.message}</td>
          <td><span class="badge-status \${f.status === 'RESOLVED' ? 'status-active' : 'status-expired'}">\${f.status || 'OPEN'}</span></td>
          <td>
            \${f.status !== 'RESOLVED' ? \`<button class="btn btn-secondary btn-sm" onclick="resolveFeedback('\${f.id}')">Resolve</button>\` : '✓ Resolved'}
          </td>
        </tr>
      \`).join('');
    }

    async function resolveFeedback(id) {
      const res = await apiFetch('/v1/admin/feedback/' + id + '/resolve', { method: 'POST', body: JSON.stringify({}) });
      if (res) loadFeedback();
    }

    async function loadAbuse() {
      const data = await apiFetch('/v1/admin/abuse');
      if (!data) return;
      const tbody = document.getElementById('abuseTableBody');
      if (!data.flaggedIps.length) {
        tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;">No abuse signals flagged.</td></tr>';
        return;
      }
      tbody.innerHTML = data.flaggedIps.map(a => \`
        <tr>
          <td><code>\${a.ip_hash}</code></td>
          <td><strong>\${a.request_count}</strong> requests</td>
          <td>\${a.window_start}</td>
          <td>\${new Date(a.updated_at).toLocaleTimeString()}</td>
        </tr>
      \`).join('');
    }

    async function loadAuditLog() {
      const data = await apiFetch('/v1/admin/audit-log');
      if (!data) return;
      const tbody = document.getElementById('auditLogTableBody');
      if (!data.auditLogs.length) {
        tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;">No audit actions recorded yet.</td></tr>';
        return;
      }
      tbody.innerHTML = data.auditLogs.map(l => \`
        <tr>
          <td>\${new Date(l.created_at).toLocaleString()}</td>
          <td>\${l.admin_email}</td>
          <td><strong>\${l.action}</strong></td>
          <td><code>\${(l.target_id || '-').substring(0, 24)}</code></td>
          <td><pre style="font-size:0.75rem; max-width:300px; overflow:hidden; text-overflow:ellipsis;">\${l.details_json}</pre></td>
        </tr>
      \`).join('');
    }

    // Modal Helpers
    function showModal(title, bodyHtml, onConfirm) {
      document.getElementById('modalTitle').textContent = title;
      document.getElementById('modalBody').innerHTML = bodyHtml;
      document.getElementById('modalConfirmBtn').onclick = onConfirm;
      document.getElementById('actionModal').classList.add('active');
    }

    function closeModal() {
      document.getElementById('actionModal').classList.remove('active');
    }

    function showCreditModal(instId) {
      showModal('Adjust Credits for ' + instId.substring(0, 12) + '...', \`
        <div class="form-group">
          <label class="form-label">Credits to Grant (+) or Revoke (-)</label>
          <input type="number" id="modalCreditDelta" class="input-field" value="5">
        </div>
        <div class="form-group">
          <label class="form-label">Reason</label>
          <input type="text" id="modalCreditReason" class="input-field" placeholder="e.g. Customer support goodwill">
        </div>
      \`, async () => {
        const delta = parseInt(document.getElementById('modalCreditDelta').value, 10);
        const reason = document.getElementById('modalCreditReason').value.trim();
        if (!reason) { alert('Reason required'); return; }
        const res = await apiFetch('/v1/admin/installations/' + instId + '/grant-credits', {
          method: 'POST',
          body: JSON.stringify({ creditsDelta: delta, reason })
        });
        if (res) {
          closeModal();
          alert(res.message);
          loadInstallations();
        }
      });
    }

    function showBanModal(instId, currentlyBanned) {
      const actionName = currentlyBanned ? 'Unban' : 'Ban';
      showModal(actionName + ' Installation ' + instId.substring(0, 12) + '...', \`
        <div class="form-group">
          <label class="form-label">Reason for \${actionName}</label>
          <input type="text" id="modalBanReason" class="input-field" placeholder="e.g. Abuse of API rate limits">
        </div>
      \`, async () => {
        const reason = document.getElementById('modalBanReason').value.trim();
        if (!reason) { alert('Reason required'); return; }
        const res = await apiFetch('/v1/admin/installations/' + instId + '/ban', {
          method: 'POST',
          body: JSON.stringify({ banned: !currentlyBanned, reason })
        });
        if (res) {
          closeModal();
          alert(res.message);
          loadInstallations();
        }
      });
    }

    // Start UI
    window.addEventListener('DOMContentLoaded', init);
  </script>
</body>
</html>`;
}
