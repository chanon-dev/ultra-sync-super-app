import http from 'k6/http';
import { check, sleep } from 'k6';
import { Options } from 'k6/options';
import { Rate, Trend, Counter } from 'k6/metrics';
import { BASE_URL, register, login, bearerHeaders } from './utils/auth';
import { ApiResponse, WalletBalance, Transaction, SetupData } from './types';

const errorRate = new Rate('error_rate');
const balanceDuration = new Trend('balance_duration', true);
const topupDuration = new Trend('topup_duration', true);
const topupCount = new Counter('topup_count');

export const options: Options = {
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

export function setup(): SetupData {
  const email = 'wallet-load@example.com';
  register(email, 'Wallet@1234');
  const token = login(email, 'Wallet@1234');
  return { token };
}

export default function (data: SetupData): void {
  if (!data.token) return;

  const authHeaders = bearerHeaders(data.token);

  // ── Get balance ───────────────────────────────────────────────────────────
  const balStart = Date.now();
  const balRes = http.get(`${BASE_URL}/api/v1/wallet/balance`, { headers: authHeaders });
  balanceDuration.add(Date.now() - balStart);

  const balOk = check(balRes, {
    'balance status 200': (r) => r.status === 200,
    'balance has balance field': (r) => {
      try {
        return typeof (JSON.parse(r.body as string) as ApiResponse<WalletBalance>).data?.balance !== 'undefined';
      } catch {
        return false;
      }
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
    { headers: { ...authHeaders, 'X-Idempotency-Key': idempotencyKey } },
  );
  topupDuration.add(Date.now() - topupStart);
  topupCount.add(1);

  const topupOk = check(topupRes, {
    'topup status 200': (r) => r.status === 200,
    'topup has transaction id': (r) => {
      try {
        return !!(JSON.parse(r.body as string) as ApiResponse<Transaction>).data?.id;
      } catch {
        return false;
      }
    },
  });
  errorRate.add(!topupOk);

  sleep(0.5);

  // ── Idempotency: replay same key ─────────────────────────────────────────
  const replayRes = http.post(
    `${BASE_URL}/api/v1/wallet/topup`,
    JSON.stringify({ amount: '100.0000' }),
    { headers: { ...authHeaders, 'X-Idempotency-Key': idempotencyKey } },
  );
  check(replayRes, { 'idempotent replay returns 200': (r) => r.status === 200 });

  sleep(0.5);

  // ── List transactions ─────────────────────────────────────────────────────
  const txRes = http.get(
    `${BASE_URL}/api/v1/wallet/transactions?limit=10`,
    { headers: authHeaders },
  );
  check(txRes, {
    'transactions status 200': (r) => r.status === 200,
    'transactions is array': (r) => {
      try {
        return Array.isArray((JSON.parse(r.body as string) as ApiResponse<Transaction[]>).data);
      } catch {
        return false;
      }
    },
  });

  sleep(1);
}
