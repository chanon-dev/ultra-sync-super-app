import http from 'k6/http';
import { check, sleep } from 'k6';
import { Options } from 'k6/options';
import { Rate, Trend } from 'k6/metrics';
import { BASE_URL, JSON_HEADERS, register } from './utils/auth';
import { ApiResponse, AuthData } from './types';

const errorRate = new Rate('error_rate');
const loginDuration = new Trend('login_duration', true);
const registerDuration = new Trend('register_duration', true);

export const options: Options = {
  stages: [
    { duration: '30s', target: 20 },
    { duration: '1m',  target: 50 },
    { duration: '30s', target: 0  },
  ],
  thresholds: {
    http_req_failed:   ['rate<0.01'],
    http_req_duration: ['p(99)<500'],
    error_rate:        ['rate<0.02'],
  },
};

function uniqueEmail(): string {
  return `load-test-${Date.now()}-${Math.random().toString(36).slice(2)}@example.com`;
}

export interface AuthSetupData {
  sharedEmail: string;
}

export function setup(): AuthSetupData {
  const sharedEmail = 'shared-load-user@example.com';
  register(sharedEmail, 'Load@1234');
  return { sharedEmail };
}

export default function (data: AuthSetupData): void {
  // ── Register ──────────────────────────────────────────────────────────────
  const regEmail = uniqueEmail();
  const regStart = Date.now();
  const regRes = http.post(
    `${BASE_URL}/api/v1/auth/register`,
    JSON.stringify({ email: regEmail, password: 'Test@1234', role: 'user' }),
    { headers: JSON_HEADERS },
  );
  registerDuration.add(Date.now() - regStart);

  const regOk = check(regRes, {
    'register status 201': (r) => r.status === 201,
    'register has user id': (r) => {
      try {
        return !!(JSON.parse(r.body as string) as ApiResponse<AuthData>).data?.id;
      } catch {
        return false;
      }
    },
  });
  errorRate.add(!regOk);

  sleep(0.5);

  // ── Login (shared user) ───────────────────────────────────────────────────
  const loginStart = Date.now();
  const loginRes = http.post(
    `${BASE_URL}/api/v1/auth/login`,
    JSON.stringify({ email: data.sharedEmail, password: 'Load@1234' }),
    { headers: JSON_HEADERS },
  );
  loginDuration.add(Date.now() - loginStart);

  const loginOk = check(loginRes, {
    'login status 200': (r) => r.status === 200,
    'login has access_token': (r) => {
      try {
        return !!(JSON.parse(r.body as string) as ApiResponse<AuthData>).data?.access_token;
      } catch {
        return false;
      }
    },
  });
  errorRate.add(!loginOk);

  sleep(1);

  // ── Wrong credentials (401 expected) ──────────────────────────────────────
  const badRes = http.post(
    `${BASE_URL}/api/v1/auth/login`,
    JSON.stringify({ email: 'nobody@example.com', password: 'wrong' }),
    { headers: JSON_HEADERS },
  );
  check(badRes, { 'bad login returns 401': (r) => r.status === 401 });

  sleep(1);
}
