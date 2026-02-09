import type {
  ApiChatRequest,
  ApiChatResponse,
  ApiSchemaResponse,
  QueryResult,
} from "@/types";

const API_BASE_URL: string =
  process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8080";

/**
 * Generic fetch wrapper with error handling and JSON parsing.
 */
async function apiFetch<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  const url = `${API_BASE_URL}${endpoint}`;

  const defaultHeaders: HeadersInit = {
    "Content-Type": "application/json",
    Accept: "application/json",
  };

  const response = await fetch(url, {
    ...options,
    headers: {
      ...defaultHeaders,
      ...options.headers,
    },
  });

  if (!response.ok) {
    const errorBody = await response.text().catch(() => "Unknown error");
    throw new Error(
      `API request failed: ${response.status} ${response.statusText} - ${errorBody}`
    );
  }

  return response.json() as Promise<T>;
}

/**
 * Send a chat message to the API and receive the assistant's response.
 */
export async function sendMessage(
  request: ApiChatRequest
): Promise<ApiChatResponse> {
  return apiFetch<ApiChatResponse>("/api/chat", {
    method: "POST",
    body: JSON.stringify(request),
  });
}

/**
 * Retrieve the database schema information.
 */
export async function getSchema(): Promise<ApiSchemaResponse> {
  return apiFetch<ApiSchemaResponse>("/api/schema");
}

/**
 * Execute a raw SQL query against the database.
 */
export async function executeQuery(sql: string): Promise<QueryResult> {
  const response = await apiFetch<{
    status: string;
    data: QueryResult;
  }>("/api/execute", {
    method: "POST",
    body: JSON.stringify({ sql }),
  });
  return response.data;
}

/**
 * Check if the API backend is reachable and healthy.
 */
export async function healthCheck(): Promise<boolean> {
  try {
    const response = await apiFetch<{ status: string }>("/api/health");
    return response.status === "ok" || response.status === "healthy";
  } catch {
    return false;
  }
}
