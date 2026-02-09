export interface ChatMessage {
  id: string;
  role: "user" | "assistant";
  content: string;
  timestamp: Date;
  sqlQuery?: string;
  queryResults?: QueryResult;
  explanation?: string;
  suggestedVisualization?: string;
  isLoading?: boolean;
  isError?: boolean;
}

export interface QueryResult {
  columns: string[];
  rows: Record<string, unknown>[];
  rowCount: number;
}

export interface ApiChatRequest {
  message: string;
  session_id?: string;
}

export interface ApiChatResponse {
  status: string;
  data: {
    session_id: string;
    sql_query: string | null;
    explanation: string;
    suggested_visualization: string | null;
    results: Record<string, unknown>[] | null;
    row_count: number;
    columns: string[];
    query_error: string | null;
  };
  message: string;
}

export interface ApiSchemaResponse {
  status: string;
  data: {
    schema: string;
    tables: string[];
  };
}

export interface ApiHealthResponse {
  status: string;
  message: string;
}
