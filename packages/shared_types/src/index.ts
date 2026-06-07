// Shared type definitions for Qubix
export interface HealthStatus {
  status: string;
  version: string;
  database: string;
  timestamp: string;
}

export interface User {
  id: string;
  email: string;
  displayName?: string;
  avatarUrl?: string;
  createdAt: string;
  updatedAt: string;
}
