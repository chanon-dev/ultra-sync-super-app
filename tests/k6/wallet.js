import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

const errorRate = new Rate('error_rate');
const balanceDuration = new Trend('balance_duration', true);
const topupDuration = new Trend('topup_duration', true);
const topupCount = new Counter('topup_count');

export const options = {
  stages: [
    { duration: '30s', target: 10 },
    { duration: '2m',  target: 30 },
    { duration: '30s', target: 0  },
  ],
  thresholds: {
    http_req_failed:   ['rate<0.01'],
    http_req_duration: ['p(95)<600'],
    error_rate:        ['rate<0.02'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

// Authenticate and return a bearer token.
function login(email, password) {
  const res = http.post(
    `${BASE_URL}/api/v1/auth/login`,
    JSON.stringify({ email, password }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  if (res.status !== 200) return null;
  return JSON.parse(res.body)?.data?.access_token || null;
}

export function setup() {
  const email = `wallet-load@example.com`;
  http.post(
    `${BASE_URL}/api/v1/auth/register`,
    JSON.stringify({ email, password: 'Wallet@1234', role: 'user' }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  const token = login(email, 'Wallet@1234');
  return { token };
}

export default function (data) {
  if (!data.token) return;

  const authHeaders = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${data.token}`,
  };

  // ── Get balance ───────────────────────────────────────────────────────────
  const balStart = Date.now();
  const balRes = http.get(`${BASE_URL}/api/v1/wallet/balance`, { headers: authHeaders });
  balanceDuration.add(Date.now() - balStart);

  const balOk = check(balRes, {
    'balance status 200': (r) => r.status === 200,
    'balance has balance field': (r) => {
      try { return typeof JSON.parse(r.body).data?.balance !== 'undefined'; } catch { return false; }
    },
  });
  errorRate.add(!balOk);

  sleep(0.5);

  // ── Top up ────────────────────────────────────────────────────────────────
  const idempotencyKey = `k6-${Date.now()}-${__VU}-${__ITER}`;
  const topupStart = Date.now();
  const topupRes = http.post(
    `${BASE_URL}/api/v1/wallet/topup`,
    JSON.stringify({ amount: '100.0000' }),
    {
      headers: {
        ...authHeaders,
        'X-Idempotency-Key': idempotencyKey,
      },
    },
  );
  topupDuration.add(Date.now() - topupStart);
  topupCount.add(1);

  const topupOk = check(topupRes, {
    'topup status 200': (r) => r.status === 200,
    'topup has transaction id': (r) => {
      try { return !!JSON.parse(r.body).data?.id; } catch { return false; }
    },
  });
  errorRate.add(!topupOk);

  sleep(0.5);

  // ── Idempotency: replay same key ─────────────────────────────────────────
  const replayRes = http.post(
    `${BASE_URL}/api/v1/wallet/topup`,
    JSON.stringify({ amount: '100.0000' }),
    {
      headers: {
        ...authHeaders,
        'X-Idempotency-Key': idempotencyKey,
      },
    },
  );
  check(replayRes, {
    'idempotent replay returns 200': (r) => r.status === 200,
  });

  sleep(0.5);

  // ── List transactions ─────────────────────────────────────────────────────
  const txRes = http.get(`${BASE_URL}/api/v1/wallet/transactions?limit=10`, { headers: authHeaders });
  check(txRes, {
    'transactions status 200': (r) => r.status === 200,
    'transactions is array': (r) => {
      try { return Array.isArray(JSON.parse(r.body).data); } catch { return false; }
    },
  });

  sleep(1);
}
