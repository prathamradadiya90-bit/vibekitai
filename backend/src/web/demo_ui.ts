export function getWebDemoHtml(): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>VibeKit AI — Interactive Web App</title>
  <link rel="icon" type="image/svg+xml" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>⚡</text></svg>">
  <style>
    :root {
      --bg: #090d16;
      --surface: #111827;
      --card: #1f2937;
      --border: #374151;
      --primary: #8b5cf6;
      --primary-light: #a78bfa;
      --accent: #ec4899;
      --cyan: #06b6d4;
      --text: #f9fafb;
      --text-muted: #9ca3af;
      --radius: 18px;
    }

    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
    body {
      background: radial-gradient(circle at 50% 0%, #1e1b4b 0%, #090d16 80%);
      color: var(--text);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 24px 16px;
    }

    .header-bar {
      width: 100%;
      max-width: 480px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 20px;
    }

    .brand {
      display: flex;
      align-items: center;
      gap: 10px;
      font-size: 22px;
      font-weight: 800;
      letter-spacing: -0.5px;
      background: linear-gradient(135deg, #a78bfa, #ec4899);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }

    .streak-badge {
      display: flex;
      align-items: center;
      gap: 6px;
      background: rgba(236, 72, 153, 0.15);
      border: 1px solid rgba(236, 72, 153, 0.3);
      padding: 6px 14px;
      border-radius: 9999px;
      font-size: 13px;
      font-weight: 700;
      color: #f472b6;
    }

    .phone-container {
      width: 100%;
      max-width: 440px;
      background: var(--surface);
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 36px;
      box-shadow: 0 25px 60px -15px rgba(0, 0, 0, 0.8), 0 0 30px rgba(139, 92, 246, 0.15);
      overflow: hidden;
      display: flex;
      flex-direction: column;
      min-height: 720px;
    }

    .nav-tabs {
      display: flex;
      background: #0f172a;
      border-bottom: 1px solid var(--border);
      padding: 6px;
      gap: 4px;
    }

    .tab-btn {
      flex: 1;
      background: transparent;
      border: none;
      color: var(--text-muted);
      padding: 10px 4px;
      font-size: 12px;
      font-weight: 600;
      cursor: pointer;
      border-radius: 12px;
      transition: all 0.2s;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 4px;
    }

    .tab-btn.active {
      background: rgba(139, 92, 246, 0.2);
      color: var(--primary-light);
    }

    .tab-content {
      display: none;
      padding: 20px;
      flex: 1;
      overflow-y: auto;
    }

    .tab-content.active {
      display: block;
    }

    .section-title {
      font-size: 18px;
      font-weight: 700;
      margin-bottom: 4px;
    }

    .section-desc {
      font-size: 13px;
      color: var(--text-muted);
      margin-bottom: 16px;
    }

    label {
      font-size: 12px;
      font-weight: 600;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 0.5px;
      display: block;
      margin-bottom: 6px;
    }

    textarea, input, select {
      width: 100%;
      background: var(--card);
      border: 1px solid var(--border);
      color: var(--text);
      padding: 12px 14px;
      border-radius: 14px;
      font-size: 14px;
      outline: none;
      transition: border-color 0.2s;
      margin-bottom: 14px;
    }

    textarea:focus, input:focus, select:focus {
      border-color: var(--primary-light);
    }

    .chips {
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
      margin-bottom: 16px;
    }

    .chip {
      background: var(--card);
      border: 1px solid var(--border);
      padding: 6px 12px;
      border-radius: 999px;
      font-size: 12px;
      cursor: pointer;
      color: var(--text-muted);
      transition: all 0.2s;
    }

    .chip.active {
      background: var(--primary);
      color: white;
      border-color: var(--primary);
    }

    .submit-btn {
      width: 100%;
      background: linear-gradient(135deg, #8b5cf6, #ec4899);
      color: white;
      border: none;
      padding: 14px;
      border-radius: 14px;
      font-size: 15px;
      font-weight: 700;
      cursor: pointer;
      box-shadow: 0 4px 15px rgba(139, 92, 246, 0.4);
      transition: opacity 0.2s, transform 0.1s;
    }

    .submit-btn:active {
      transform: scale(0.98);
    }

    .submit-btn:disabled {
      opacity: 0.6;
      cursor: not-allowed;
    }

    .results {
      margin-top: 20px;
    }

    .result-card {
      background: var(--card);
      border: 1px solid var(--border);
      padding: 14px 16px;
      border-radius: 14px;
      margin-bottom: 12px;
      position: relative;
      animation: fadeIn 0.3s ease;
    }

    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(6px); }
      to { opacity: 1; transform: translateY(0); }
    }

    .result-text {
      font-size: 14px;
      line-height: 1.5;
      margin-bottom: 10px;
      color: #f3f4f6;
    }

    .card-actions {
      display: flex;
      justify-content: flex-end;
      gap: 8px;
    }

    .action-btn {
      background: rgba(255, 255, 255, 0.08);
      border: none;
      color: var(--primary-light);
      padding: 5px 12px;
      border-radius: 8px;
      font-size: 12px;
      cursor: pointer;
      font-weight: 600;
    }

    .action-btn:hover {
      background: rgba(255, 255, 255, 0.16);
    }

    .score-circle {
      width: 70px;
      height: 70px;
      border-radius: 50%;
      background: conic-gradient(#8b5cf6 calc(var(--score) * 1%), #374151 0);
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 12px auto;
      position: relative;
    }

    .score-circle::after {
      content: attr(data-score);
      position: absolute;
      width: 54px;
      height: 54px;
      border-radius: 50%;
      background: var(--surface);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 18px;
      font-weight: 800;
      color: #f3f4f6;
    }

    .roast-badge {
      display: inline-block;
      padding: 3px 10px;
      border-radius: 6px;
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      background: rgba(239, 68, 68, 0.2);
      color: #f87171;
      margin-bottom: 8px;
    }

    .footer-note {
      margin-top: 16px;
      font-size: 12px;
      color: var(--text-muted);
      text-align: center;
    }

    .footer-note a {
      color: var(--primary-light);
      text-decoration: none;
    }
  </style>
</head>
<body>

  <div class="header-bar">
    <div class="brand">⚡ VibeKit AI</div>
    <div class="streak-badge" id="topStreak">🔥 1 Day Streak</div>
  </div>

  <div class="phone-container">
    <div style="padding: 12px 20px 0;">
      <label for="demoLanguage">Language</label>
      <select id="demoLanguage" style="margin-bottom: 4px;">
        <option value="English">English</option>
        <option value="Hindi">Hindi</option>
        <option value="Hinglish">Hinglish</option>
        <option value="Gujarati">Gujarati</option>
      </select>
    </div>

    <div class="nav-tabs">
      <button class="tab-btn active" data-tab="replies" onclick="switchTab('replies')">
        <span>💬</span> Replies
      </button>
      <button class="tab-btn" data-tab="studio" onclick="switchTab('studio')">
        <span>✨</span> Studio
      </button>
      <button class="tab-btn" data-tab="roast" onclick="switchTab('roast')">
        <span>🔥</span> Roast
      </button>
      <button class="tab-btn" data-tab="card" onclick="switchTab('card')">
        <span>🎨</span> Card
      </button>
    </div>

    <!-- TAB 1: SMART REPLIES -->
    <div id="tab-replies" class="tab-content active">
      <div class="section-title">Smart Chat Replies</div>
      <div class="section-desc">Generate magnetic comebacks, flirty openers, or savage texts.</div>

      <label>Received Message</label>
      <textarea id="replyInput" rows="3" placeholder="e.g. 'Hey, what are you doing this weekend?'">Hey stranger, long time no see! What's up?</textarea>

      <label>Tone</label>
      <div class="chips" id="replyToneChips">
        <div class="chip active" data-val="Witty">Witty</div>
        <div class="chip" data-val="Flirty">Flirty</div>
        <div class="chip" data-val="Chill">Chill</div>
        <div class="chip" data-val="Savage">Savage</div>
        <div class="chip" data-val="Professional">Professional</div>
      </div>

      <button class="submit-btn" id="generateReplyBtn" onclick="generateReplies()">⚡ Generate Replies</button>

      <div class="results" id="replyResults"></div>
    </div>

    <!-- TAB 2: STUDIO (CAPTIONS & BIOS) -->
    <div id="tab-studio" class="tab-content">
      <div class="section-title">Caption & Bio Studio</div>
      <div class="section-desc">Viral hooks, hashtags, and aesthetic social media bios.</div>

      <label>Platform</label>
      <select id="studioPlatform">
        <option value="Instagram Reels">Instagram Reels</option>
        <option value="TikTok">TikTok</option>
        <option value="Instagram Post">Instagram Post</option>
        <option value="Threads & X">Threads & X</option>
        <option value="YouTube Shorts">YouTube Shorts</option>
        <option value="General Social Media">General Social Media</option>
      </select>

      <label>Topic / Idea</label>
      <textarea id="studioInput" rows="3" placeholder="e.g. Sunset rooftop party in Tokyo">Late night coding session fueled by matcha and lo-fi beats</textarea>

      <label>Vibe</label>
      <div class="chips" id="studioToneChips">
        <div class="chip active" data-val="Aesthetic">Aesthetic</div>
        <div class="chip" data-val="Trendy">Trendy</div>
        <div class="chip" data-val="Witty">Witty</div>
        <div class="chip" data-val="Savage">Savage</div>
        <div class="chip" data-val="Hustle">Hustle</div>
      </div>

      <button class="submit-btn" id="generateStudioBtn" onclick="generateCaptions()">✨ Generate Captions</button>

      <div class="results" id="studioResults"></div>
    </div>

    <!-- TAB 3: VIBE CHECK & ROASTER -->
    <div id="tab-roast" class="tab-content">
      <div class="section-title">Vibe Check & Roaster</div>
      <div class="section-desc">Rate energy, roast desperation, and get leveled-up rewrites.</div>

      <label>Draft Message to Rate</label>
      <textarea id="roastInput" rows="3" placeholder="Paste your text here...">Hey sorry to bother you again, did you see my last message? Let me know whenever you're free, no rush!!</textarea>

      <button class="submit-btn" id="roastBtn" onclick="runVibeCheck()">🔥 Rate & Roast My Message</button>

      <div class="results" id="roastResults"></div>
    </div>

    <!-- TAB 4: AESTHETIC CARD MAKER -->
    <div id="tab-card" class="tab-content">
      <div class="section-title">Aesthetic Card Maker</div>
      <div class="section-desc">Create shareable graphic quote cards with 1 tap.</div>

      <div id="cardPreview" style="background: linear-gradient(135deg, #4f46e5, #ec4899); border-radius: 20px; padding: 24px; min-height: 220px; display: flex; flex-direction: column; justify-content: space-between; margin-bottom: 16px; box-shadow: 0 10px 25px rgba(79, 70, 229, 0.3);">
        <div style="font-size: 11px; text-transform: uppercase; letter-spacing: 1.5px; opacity: 0.8; font-weight: 700;">⚡ VIBEKIT QUOTE</div>
        <div id="cardText" style="font-size: 17px; font-weight: 700; line-height: 1.4; color: white;">"Not ignoring you, just romanticizing my peace."</div>
        <div style="display: flex; justify-content: space-between; align-items: center; font-size: 12px; opacity: 0.85;">
          <span>@vibekit.ai</span>
          <span>#maincharacter</span>
        </div>
      </div>

      <label>Customize Text</label>
      <input type="text" id="cardCustomText" value="Not ignoring you, just romanticizing my peace." oninput="updateCardText(this.value)">

      <label>Theme</label>
      <div class="chips">
        <div class="chip active" onclick="setCardTheme('linear-gradient(135deg, #4f46e5, #ec4899)')">Cyberpunk</div>
        <div class="chip" onclick="setCardTheme('linear-gradient(135deg, #090d16, #1e293b)')">Midnight Obsidian</div>
        <div class="chip" onclick="setCardTheme('linear-gradient(135deg, #f59e0b, #ef4444)')">Sunset Blaze</div>
        <div class="chip" onclick="setCardTheme('linear-gradient(135deg, #06b6d4, #3b82f6)')">Neon Ocean</div>
      </div>

      <button class="submit-btn" onclick="copyCardQuote()">📋 Copy Quote Text</button>
    </div>
  </div>

  <div class="footer-note">
    Running live on Cloudflare Workers edge • <a href="/privacy">Privacy Policy</a> • <a href="/admin">Admin Console</a>
  </div>

  <script>
    const INSTALL_ID = localStorage.getItem('vibekit_install_id') || 'demo-' + Math.random().toString(36).substring(2, 10);
    localStorage.setItem('vibekit_install_id', INSTALL_ID);

    function switchTab(tab) {
      document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
      const activeBtn = document.querySelector('.tab-btn[data-tab="' + tab + '"]');
      if (activeBtn) activeBtn.classList.add('active');
      document.getElementById('tab-' + tab).classList.add('active');
    }

    // Chip click handlers
    document.querySelectorAll('.chips').forEach(container => {
      container.addEventListener('click', (e) => {
        if (e.target.classList.contains('chip')) {
          container.querySelectorAll('.chip').forEach(c => c.classList.remove('active'));
          e.target.classList.add('active');
        }
      });
    });

    function createActionCard(text, extraMeta) {
      const card = document.createElement('div');
      card.className = 'result-card';

      const body = document.createElement('div');
      body.className = 'result-text';
      body.textContent = text;
      card.appendChild(body);

      if (extraMeta) {
        const meta = document.createElement('div');
        meta.style.cssText = 'font-size:12px; color:#a78bfa; margin-bottom:8px;';
        meta.textContent = extraMeta;
        card.appendChild(meta);
      }

      const actions = document.createElement('div');
      actions.className = 'card-actions';

      const cardBtn = document.createElement('button');
      cardBtn.className = 'action-btn';
      cardBtn.type = 'button';
      cardBtn.textContent = '🎨 Put on Card';
      cardBtn.addEventListener('click', () => sendToCard(text));

      const copyBtn = document.createElement('button');
      copyBtn.className = 'action-btn';
      copyBtn.type = 'button';
      copyBtn.textContent = '📋 Copy';
      copyBtn.addEventListener('click', () => copyText(text));

      actions.appendChild(cardBtn);
      actions.appendChild(copyBtn);
      card.appendChild(actions);
      return card;
    }

    function renderErrorCard(resContainer, message) {
      resContainer.innerHTML = '';
      const errCard = document.createElement('div');
      errCard.className = 'result-card';
      errCard.style.color = '#f87171';
      errCard.textContent = message;
      resContainer.appendChild(errCard);
    }

    async function generateReplies() {
      const btn = document.getElementById('generateReplyBtn');
      const input = document.getElementById('replyInput').value.trim();
      const tone = document.querySelector('#replyToneChips .chip.active').dataset.val;
      const resContainer = document.getElementById('replyResults');

      if (!input) return alert('Please enter a message.');
      btn.disabled = true;
      btn.innerText = '⚡ Thinking...';
      resContainer.innerHTML = '';

      try {
        const language = (document.getElementById('demoLanguage') && document.getElementById('demoLanguage').value) || 'English';
        const res = await fetch('/v1/generations/reply', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'X-Installation-Id': INSTALL_ID },
          body: JSON.stringify({ message: input, tone: tone, language: language, length: 'medium', count: 3 })
        });
        const data = await res.json();
        if (!res.ok) {
          renderErrorCard(resContainer, data?.error?.message || 'Generation failed');
        } else if (data.suggestions && data.suggestions.length) {
          data.suggestions.forEach(s => {
            resContainer.appendChild(createActionCard(String(s || ''), ''));
          });
        } else {
          resContainer.innerHTML = '<div class="result-card">No replies returned. Try another message!</div>';
        }
      } catch (err) {
        renderErrorCard(resContainer, 'Error: ' + (err?.message || 'Request failed'));
      } finally {
        btn.disabled = false;
        btn.innerText = '⚡ Generate Replies';
      }
    }

    async function generateCaptions() {
      const btn = document.getElementById('generateStudioBtn');
      const topic = document.getElementById('studioInput').value.trim();
      const platform = document.getElementById('studioPlatform').value;
      const tone = document.querySelector('#studioToneChips .chip.active').dataset.val;
      const resContainer = document.getElementById('studioResults');

      if (!topic) return alert('Please enter a topic.');
      btn.disabled = true;
      btn.innerText = '✨ Generating...';
      resContainer.innerHTML = '';

      try {
        const language = (document.getElementById('demoLanguage') && document.getElementById('demoLanguage').value) || 'English';
        const res = await fetch('/v1/generations/caption', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'X-Installation-Id': INSTALL_ID },
          body: JSON.stringify({ topic: topic, platform: platform, tone: tone, language: language, length: 'medium', include_hooks: true, include_hashtags: true })
        });
        const data = await res.json();
        if (!res.ok) {
          renderErrorCard(resContainer, data?.error?.message || 'Generation failed');
        } else if ((data.captions && data.captions.length) || (data.hooks && data.hooks.length)) {
          const allTags = (data.hashtags || []).map(h => String(h).startsWith('#') ? h : '#' + h).join(' ');
          const ctas = (data.call_to_actions || []).filter(Boolean);

          if (data.hooks && data.hooks.length) {
            const hooksHeader = document.createElement('div');
            hooksHeader.style.cssText = 'font-size:12px; font-weight:700; margin:8px 0 6px 4px; color:#a78bfa;';
            hooksHeader.textContent = 'SCROLL-STOPPING HOOKS';
            resContainer.appendChild(hooksHeader);
            data.hooks.forEach(h => resContainer.appendChild(createActionCard(String(h || ''), '')));
          }

          if (data.captions && data.captions.length) {
            const capHeader = document.createElement('div');
            capHeader.style.cssText = 'font-size:12px; font-weight:700; margin:12px 0 6px 4px; color:#a78bfa;';
            capHeader.textContent = 'CAPTIONS';
            resContainer.appendChild(capHeader);
            data.captions.forEach((c, i) => {
              const meta = i === 0 ? [allTags, ctas[0] ? 'CTA: ' + ctas[0] : ''].filter(Boolean).join(' • ') : (ctas[i] ? 'CTA: ' + ctas[i] : '');
              resContainer.appendChild(createActionCard(String(c || ''), meta));
            });
          }

          if (ctas.length) {
            const ctaHeader = document.createElement('div');
            ctaHeader.style.cssText = 'font-size:12px; font-weight:700; margin:12px 0 6px 4px; color:#a78bfa;';
            ctaHeader.textContent = 'CALLS TO ACTION';
            resContainer.appendChild(ctaHeader);
            ctas.forEach(cta => resContainer.appendChild(createActionCard(String(cta || ''), '')));
          }
        } else {
          resContainer.innerHTML = '<div class="result-card">No captions returned. Try another topic!</div>';
        }
      } catch (err) {
        renderErrorCard(resContainer, 'Error: ' + (err?.message || 'Request failed'));
      } finally {
        btn.disabled = false;
        btn.innerText = '✨ Generate Captions';
      }
    }

    async function runVibeCheck() {
      const btn = document.getElementById('roastBtn');
      const text = document.getElementById('roastInput').value.trim();
      const resContainer = document.getElementById('roastResults');

      if (!text) return alert('Please enter text to rate.');
      btn.disabled = true;
      btn.innerText = '🔥 Analyzing Energy...';
      resContainer.innerHTML = '';

      try {
        const language = (document.getElementById('demoLanguage') && document.getElementById('demoLanguage').value) || 'English';
        const res = await fetch('/v1/generations/vibe-check', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'X-Installation-Id': INSTALL_ID },
          body: JSON.stringify({ text: text, mode: 'roast', language: language })
        });
        const data = await res.json();
        if (!res.ok) {
          renderErrorCard(resContainer, data?.error?.message || 'Analysis failed');
        } else {
          const score = Math.max(0, Math.min(100, Number(data.score ?? 42) || 42));
          resContainer.innerHTML = \`
            <div class="result-card" style="text-align: center;">
              <div class="score-circle" style="--score: \${score};" data-score="\${score}"></div>
              <div style="font-size: 16px; font-weight: 800; margin-bottom: 4px;">\${escapeHtml(data.title || 'Vibe Check Result')}</div>
              <div style="font-size: 13px; color: #f87171; margin-bottom: 12px; font-style: italic;">"\${escapeHtml(data.verdict || '')}"</div>
              \${data.tags ? data.tags.map(t => '<span class="chip" style="pointer-events:none; margin:2px;">' + escapeHtml(String(t).startsWith('#') ? t : '#' + t) + '</span>').join(' ') : ''}
            </div>
          \`;
          if (data.rewrites && data.rewrites.length) {
            const label = document.createElement('div');
            label.style.cssText = 'font-size: 13px; font-weight: 700; margin: 16px 0 8px 4px; color: #a78bfa;';
            label.textContent = 'UPGRADED REWRITES:';
            resContainer.appendChild(label);
            data.rewrites.forEach(rw => resContainer.appendChild(createActionCard(String(rw || ''), '')));
          }
        }
      } catch (err) {
        renderErrorCard(resContainer, 'Error: ' + (err?.message || 'Request failed'));
      } finally {
        btn.disabled = false;
        btn.innerText = '🔥 Rate & Roast My Message';
      }
    }

    function updateCardText(val) {
      document.getElementById('cardText').innerText = '"' + val + '"';
    }

    function setCardTheme(bg) {
      document.getElementById('cardPreview').style.background = bg;
    }

    function sendToCard(text) {
      document.getElementById('cardCustomText').value = text;
      document.getElementById('cardText').innerText = '"' + text + '"';
      document.querySelectorAll('.tab-btn')[3].click();
    }

    function copyCardQuote() {
      const val = document.getElementById('cardCustomText').value;
      copyText(val);
    }

    async function copyText(str) {
      try {
        if (navigator.clipboard && navigator.clipboard.writeText) {
          await navigator.clipboard.writeText(str);
          alert('Copied to clipboard!');
          return;
        }
      } catch (_) {}
      const ta = document.createElement('textarea');
      ta.value = str;
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      try { document.execCommand('copy'); } catch (_) {}
      document.body.removeChild(ta);
      alert('Copied to clipboard!');
    }

    function escapeHtml(str) {
      return String(str || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }
  </script>
</body>
</html>`;
}
