import http from 'k6/http';
import { check, sleep } from 'k6';
import { Options } from 'k6/options';
import { Rate, Trend } from 'k6/metrics';
import { BASE_URL, register, login, bearerHeaders } from './utils/auth';
import { ApiResponse, Shipment, GeoCoord, SetupData } from './types';

const errorRate = new Rate('error_rate');
const createDuration = new Trend('create_shipment_duration', true);
const listDuration = new Trend('list_shipments_duration', true);

export const options: Options = {
  stages: [
    { duration: '30s', target: 10 },
    { duration: '2m',  target: 25 },
    { duration: '30s', target: 0  },
  ],
  thresholds: {
    http_req_failed:   ['rate<0.01'],
    http_req_duration: ['p(95)<800'],
    error_rate:        ['rate<0.02'],
  },
};

export function setup(): SetupData {
  const email = 'logistics-load@example.com';
  register(email, 'Logistics@1234');
  const token = login(email, 'Logistics@1234');
  return { token };
}

function randomBangkokGeo(): GeoCoord {
  return {
    lat: 13.6 + Math.random() * 0.3,
    lng: 100.4 + Math.random() * 0.3,
  };
}

export default function (data: SetupData): void {
  if (!data.token) return;

  const authHeaders = bearerHeaders(data.token);

  // ── List shipments ────────────────────────────────────────────────────────
  const listStart = Date.now();
  const listRes = http.get(`${BASE_URL}/api/v1/shipments?limit=20`, { headers: authHeaders });
  listDuration.add(Date.now() - listStart);

  const listOk = check(listRes, {
    'list status 200': (r) => r.status === 200,
    'list has data array': (r) => {
      try {
        return Array.isArray((JSON.parse(r.body as string) as ApiResponse<Shipment[]>).data);
      } catch {
        return false;
      }
    },
  });
  errorRate.add(!listOk);

  sleep(0.5);

  // ── Create shipment ───────────────────────────────────────────────────────
  const pickup  = randomBangkokGeo();
  const dropoff = randomBangkokGeo();

  const createStart = Date.now();
  const createRes = http.post(
    `${BASE_URL}/api/v1/shipments`,
    JSON.stringify({
      pickup_lat:  pickup.lat,
      pickup_lng:  pickup.lng,
      dropoff_lat: dropoff.lat,
      dropoff_lng: dropoff.lng,
    }),
    { headers: authHeaders },
  );
  createDuration.add(Date.now() - createStart);

  const createOk = check(createRes, {
    'create status 201': (r) => r.status === 201,
    'create has shipment id': (r) => {
      try {
        return !!(JSON.parse(r.body as string) as ApiResponse<Shipment>).data?.id;
      } catch {
        return false;
      }
    },
  });
  errorRate.add(!createOk);

  // ── Get shipment detail ───────────────────────────────────────────────────
  if (createRes.status === 201) {
    const shipmentId = (JSON.parse(createRes.body as string) as ApiResponse<Shipment>)?.data?.id;
    if (shipmentId) {
      const detailRes = http.get(
        `${BASE_URL}/api/v1/shipments/${shipmentId}`,
        { headers: authHeaders },
      );
      check(detailRes, {
        'detail status 200': (r) => r.status === 200,
        'detail matches created id': (r) => {
          try {
            return (JSON.parse(r.body as string) as ApiResponse<Shipment>).data?.id === shipmentId;
          } catch {
            return false;
          }
        },
      });
    }
  }

  sleep(1);
}
