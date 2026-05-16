import http from 'k6/http';
import { ApiResponse, AuthData } from '../types';

export const BASE_URL: string = __ENV.BASE_URL || 'http://localhost:8080';

export const JSON_HEADERS = { 'Content-Type': 'application/json' } as const;

export function login(email: string, password: string): string | null {
  const res = http.post(
    `${BASE_URL}/api/v1/auth/login`,
    JSON.stringify({ email, password }),
    { headers: JSON_HEADERS },
  );
  if (res.status !== 200) return null;
  const body = JSON.parse(res.body as string) as ApiResponse<AuthData>;
  return body?.data?.access_token ?? null;
}

export function register(email: string, password: string, role = 'user'): void {
  http.post(
    `${BASE_URL}/api/v1/auth/register`,
    JSON.stringify({ email, password, role }),
    { headers: JSON_HEADERS },
  );
}

export function bearerHeaders(token: string): Record<string, string> {
  return {
    ...JSON_HEADERS,
    Authorization: `Bearer ${token}`,
  };
}
