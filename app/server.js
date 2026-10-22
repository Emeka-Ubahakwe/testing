'use strict';

if (process.env.APPLICATIONINSIGHTS_CONNECTION_STRING) {
  const { useAzureMonitor } = require('@azure/monitor-opentelemetry');
  useAzureMonitor();
}

const http = require('http');

const PORT = process.env.PORT || 8080;
const RESOURCE_ID = process.env.METRICS_RESOURCE_ID; // full resource id of this web app
const REGION = process.env.METRICS_REGION || 'uksouth';
const NAMESPACE = 'Sandbox';

let queueDepth = 0; // simulated queue, set with /queue?value=N
const held = []; // memory held by /mem
let tokenCache = { token: null, expires: 0 };

// One JSON line per log entry on stdout. App service collects stdout as console logs.
function log(level, msg, extra = {}) {
  process.stdout.write(JSON.stringify({ time: new Date().toISOString(), level, msg, ...extra }) + '\n');
}

// Token from the app's managed identity. No secrets in code or settings.
async function getToken() {
  const now = Date.now() / 1000;
  if (tokenCache.token && tokenCache.expires - 300 > now) return tokenCache.token;
  const url =
    `${process.env.IDENTITY_ENDPOINT}?api-version=2019-08-01` +
    `&resource=${encodeURIComponent('https://monitoring.azure.com/')}` +
    // Needed when the app has a user-assigned identity instead of a system one.
    (process.env.AZURE_CLIENT_ID ? `&client_id=${process.env.AZURE_CLIENT_ID}` : '');
  const res = await fetch(url, { headers: { 'X-IDENTITY-HEADER': process.env.IDENTITY_HEADER } });
  if (!res.ok) throw new Error(`token request failed: ${res.status} ${await res.text()}`);
  const body = await res.json();
  tokenCache = { token: body.access_token, expires: Number(body.expires_on) };
  return body.access_token;
}

// Send one custom metric value to azure monitor through the REST API.
async function emitMetric(name, value, dims = {}) {
  if (!RESOURCE_ID) throw new Error('METRICS_RESOURCE_ID is not set');
  const token = await getToken();
  const dimNames = Object.keys(dims);
  const series = { min: value, max: value, sum: value, count: 1 };
  const baseData = { metric: name, namespace: NAMESPACE, series: [series] };
  if (dimNames.length) {
    baseData.dimNames = dimNames;
    series.dimValues = dimNames.map((k) => String(dims[k]));
  }
  const res = await fetch(`https://${REGION}.monitoring.azure.com${RESOURCE_ID}/metrics`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ time: new Date().toISOString(), data: { baseData } }),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`metric post failed: ${res.status} ${text}`);
  log('info', 'metric sent', { metric: name, value, dims });
  return res.status;
}

// Every minute: send the simulated queue depth and a heartbeat.
if (process.env.EMIT_LOOP === 'true') {
  setInterval(async () => {
    try {
      await emitMetric('queue_depth', queueDepth, { queue: 'rdl' });
      await emitMetric('heartbeat', 1);
    } catch (err) {
      log('error', 'metric loop failed', { error: err.message });
    }
  }, 60_000);
}

function send(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const q = Object.fromEntries(url.searchParams);
  try {
    switch (url.pathname) {
      case '/':
        return send(res, 200, { ok: true, queueDepth, heldMb: held.length * 10, appInsights: Boolean(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING) });

      // Slow response. Moves HttpResponseTime.
      case '/slow': {
        const ms = Math.min(Number(q.ms || 2000), 60_000);
        await sleep(ms);
        return send(res, 200, { sleptMs: ms });
      }

      // Server error. Moves Http5xx.
      case '/fail':
        log('error', 'forced failure', { path: '/fail' });
        return send(res, Number(q.code || 500), { failed: true });

      // Busy CPU. Node runs one thread, so this also blocks other requests,
      // which makes requests wait and moves HttpQueueLength.
      case '/cpu': {
        const end = Date.now() + Math.min(Number(q.seconds || 20), 120) * 1000;
        while (Date.now() < end) Math.sqrt(Math.random());
        return send(res, 200, { burned: true });
      }

      // Hold memory in 10 MB pieces. Moves MemoryPercentage.
      case '/mem': {
        const mb = Math.min(Number(q.mb || 100), 1000);
        for (let i = 0; i < mb / 10; i++) held.push(Buffer.alloc(10 * 1024 * 1024, 1));
        return send(res, 200, { heldMb: held.length * 10 });
      }
      case '/mem/free':
        held.length = 0;
        return send(res, 200, { heldMb: 0 });

      // Set the simulated queue. The loop sends it every minute.
      case '/queue':
        queueDepth = Number(q.value || 0);
        await emitMetric('queue_depth', queueDepth, { queue: 'rdl' });
        return send(res, 200, { queueDepth });

      // A file push result, like the rows in digidown_fileup.metrics.
      case '/push': {
        const dims = { destination: q.destination || 'Convey', outcome: q.ok === '0' ? 'fail' : 'ok' };
        await emitMetric('file_push', 1, dims);
        if (q.ms) await emitMetric('file_push_duration_ms', Number(q.ms), { destination: dims.destination });
        return send(res, 200, dims);
      }

      // Any custom metric: /metric?name=x&value=5&anyDimension=value
      case '/metric': {
        const { name, value, ...dims } = q;
        if (!name) return send(res, 400, { error: 'name is required' });
        const status = await emitMetric(name, Number(value || 1), dims);
        return send(res, 200, { name, status });
      }

      // A log line on stdout: /log?level=error&msg=hello
      case '/log':
        log(q.level || 'info', q.msg || 'test log line', { source: 'sandbox' });
        return send(res, 200, { logged: true });

      default:
        return send(res, 404, { error: 'not found' });
    }
  } catch (err) {
    log('error', 'request failed', { path: url.pathname, error: err.message });
    return send(res, 500, { error: err.message });
  }
});

server.listen(PORT, () => log('info', 'sandbox app started', { port: PORT }));
