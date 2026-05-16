import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const errorRate = new Rate('error_rate');
const loginDuration = new Trend('login_duration', true);
const registerDuration = new Trend('register_duration', true);

export const options = {
  stages: [
    { duration: '30s', target: 20 },  // ramp up
    { duration: '1m',  target: 50 },  // sustained load
    { duration: '30s', target: 0  },  // ramp down
  ],
  thresholds: {
    http_req_failed:   ['rate<0.01'],   // < 1% errors
    http_req_duration: ['p(99)<500'],   // 99th pct < 500ms
    error_rate:        ['rate<0.02'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

function uniqueEmail() {
  return `load-test-${Date.now()}-${Math.random().toString(36).slice(2)}@example.com`;
}

export function setup() {
  // Pre-register a shared user for the login scenario.
  const email = `shared-load-user@example.com`;
  http.post(
    `${BASE_URL}/api/v1/auth/register`,
    JSON.stringify({ email, password: 'Load@1234', role: 'user' }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  return { sharedEmail: email };
}

export default function (data) {
  // ── Register ──────────────────────────────────────────────────────────────
  const regEmail = uniqueEmail();
  const regStart = Date.now();
  const regRes = http.post(
    `${BASE_URL}/api/v1/auth/register`,
    JSON.stringify({ email: regEmail, password: 'Test@1234', role: 'user' }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  registerDuration.add(Date.now() - regStart);

  const regOk = check(regRes, {
    'register status 201': (r) => r.status === 201,
    'register has user id': (r) => {
      try { return !!JSON.parse(r.body).data?.id; } catch { return false; }
    },
  });
  errorRate.add(!regOk);

  sleep(0.5);

  // ── Login (shared user) ───────────────────────────────────────────────────
  const loginStart = Date.now();
  const loginRes = http.post(
    `${BASE_URL}/api/v1/auth/login`,
    JSON.stringify({ email: data.sharedEmail, password: 'Load@1234' }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  loginDuration.add(Date.now() - loginStart);

  const loginOk = check(loginRes, {
    'login status 200': (r) => r.status === 200,
    'login has access_token': (r) => {
      try { return !!JSON.parse(r.body).data?.access_token; } catch { return false; }
    },
  });
  errorRate.add(!loginOk);

  sleep(1);

  // ── Wrong credentials (400/401 expected) ──────────────────────────────────
  const badRes = http.post(
    `${BASE_URL}/api/v1/auth/login`,
    JSON.stringify({ email: 'nobody@example.com', password: 'wrong' }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  check(badRes, { 'bad login returns 401': (r) => r.status === 401 });

  sleep(1);
}
