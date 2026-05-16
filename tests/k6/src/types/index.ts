export interface ApiResponse<T> {
  data: T;
  meta: {
    request_id: string;
    timestamp: string;
  };
  error: string | null;
}

export interface AuthData {
  id: string;
  access_token: string;
}

export interface WalletBalance {
  balance: string;
}

export interface Transaction {
  id: string;
  amount: string;
  type: string;
  created_at: string;
}

export interface Shipment {
  id: string;
  status: string;
  pickup_lat: number;
  pickup_lng: number;
  dropoff_lat: number;
  dropoff_lng: number;
  created_at: string;
}

export interface GeoCoord {
  lat: number;
  lng: number;
}

export interface SetupData {
  token: string | null;
}
