"use client";

import { useState, useCallback, useRef, useEffect } from "react";
import type { ChatMessage, ApiChatResponse } from "@/types";
import { sendMessage as apiSendMessage } from "@/lib/api";

function generateId(): string {
  if (typeof crypto !== "undefined" && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return `${Date.now()}-${Math.random().toString(36).substring(2, 11)}`;
}

export interface UseChatReturn {
  messages: ChatMessage[];
  isLoading: boolean;
  sendMessage: (content: string) => Promise<void>;
  clearMessages: () => void;
  sessionId: string;
}

export function useChat(): UseChatReturn {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const sessionIdRef = useRef<string>("");

  useEffect(() => {
    sessionIdRef.current = generateId();
  }, []);

  const sendMessage = useCallback(
    async (content: string) => {
      if (!content.trim() || isLoading) return;

      const userMessage: ChatMessage = {
        id: generateId(),
        role: "user",
        content: content.trim(),
        timestamp: new Date(),
      };

      const loadingMessage: ChatMessage = {
        id: generateId(),
        role: "assistant",
        content: "",
        timestamp: new Date(),
        isLoading: true,
      };

      setMessages((prev) => [...prev, userMessage, loadingMessage]);
      setIsLoading(true);

      try {
        const response: ApiChatResponse = await apiSendMessage({
          message: content.trim(),
          session_id: sessionIdRef.current,
        });

        const queryResults: import("@/types").QueryResult | undefined =
          response.data.results
            ? {
                columns: response.data.columns,
                rows: response.data.results,
                rowCount: response.data.row_count,
              }
            : undefined;

        const assistantMessage: ChatMessage = {
          id: generateId(),
          role: "assistant",
          content: response.data.explanation,
          timestamp: new Date(),
          sqlQuery: response.data.sql_query ?? undefined,
          queryResults,
          explanation: response.data.explanation,
          suggestedVisualization:
            response.data.suggested_visualization ?? undefined,
        };

        setMessages((prev) => {
          const withoutLoading = prev.filter((m) => !m.isLoading);
          return [...withoutLoading, assistantMessage];
        });
      } catch (error) {
        const errorContent =
          error instanceof Error
            ? error.message
            : "An unexpected error occurred. Please try again.";

        const errorMessage: ChatMessage = {
          id: generateId(),
          role: "assistant",
          content: `Sorry, I encountered an error: ${errorContent}`,
          timestamp: new Date(),
          isError: true,
        };

        setMessages((prev) => {
          const withoutLoading = prev.filter((m) => !m.isLoading);
          return [...withoutLoading, errorMessage];
        });
      } finally {
        setIsLoading(false);
      }
    },
    [isLoading]
  );

  const clearMessages = useCallback(() => {
    setMessages([]);
    sessionIdRef.current = generateId();
  }, []);

  return {
    messages,
    isLoading,
    sendMessage,
    clearMessages,
    sessionId: sessionIdRef.current,
  };
}
