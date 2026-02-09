"use client";

import { Bot, User, AlertCircle } from "lucide-react";
import type { ChatMessage } from "@/types";
import { SqlPreview } from "@/components/sql-preview";
import { DataTable } from "@/components/data-table";

interface MessageBubbleProps {
  message: ChatMessage;
}

export function MessageBubble({ message }: MessageBubbleProps) {
  const isUser = message.role === "user";

  if (message.isLoading) {
    return <LoadingBubble />;
  }

  return (
    <div
      className={`flex gap-3 animate-fade-in ${
        isUser ? "justify-end" : "justify-start"
      }`}
    >
      {/* Assistant avatar */}
      {!isUser && (
        <div className="flex-shrink-0 w-8 h-8 rounded-full bg-primary-subtle flex items-center justify-center mt-1">
          <Bot className="w-4 h-4 text-primary" />
        </div>
      )}

      {/* Message content */}
      <div
        className={`max-w-[85%] lg:max-w-[75%] ${isUser ? "order-first" : ""}`}
      >
        <div
          className={`rounded-2xl px-4 py-3 ${
            isUser
              ? "bg-user-bubble text-user-bubble-text rounded-br-md"
              : message.isError
                ? "bg-assistant-bubble text-assistant-bubble-text border border-error/30 rounded-bl-md"
                : "bg-assistant-bubble text-assistant-bubble-text rounded-bl-md"
          }`}
        >
          {/* Error icon */}
          {message.isError && (
            <div className="flex items-center gap-2 mb-2 text-error">
              <AlertCircle className="w-4 h-4" />
              <span className="text-xs font-medium">Error</span>
            </div>
          )}

          {/* Message text */}
          <div className="text-sm leading-relaxed whitespace-pre-wrap break-words">
            {message.content}
          </div>
        </div>

        {/* SQL Query block (outside the bubble for better layout) */}
        {message.sqlQuery && <SqlPreview sql={message.sqlQuery} />}

        {/* Explanation text */}
        {message.explanation && message.explanation !== message.content && (
          <div className="mt-2 px-4 py-2.5 rounded-lg bg-primary-subtle/50 border border-primary/10">
            <p className="text-xs text-text-secondary leading-relaxed">
              {message.explanation}
            </p>
          </div>
        )}

        {/* Query results table */}
        {message.queryResults && <DataTable data={message.queryResults} />}

        {/* Timestamp */}
        <div
          className={`mt-1.5 text-[10px] text-text-muted ${
            isUser ? "text-right" : "text-left"
          }`}
        >
          {formatTimestamp(message.timestamp)}
        </div>
      </div>

      {/* User avatar */}
      {isUser && (
        <div className="flex-shrink-0 w-8 h-8 rounded-full bg-primary flex items-center justify-center mt-1">
          <User className="w-4 h-4 text-white" />
        </div>
      )}
    </div>
  );
}

/**
 * Animated loading indicator shown while waiting for API response.
 */
function LoadingBubble() {
  return (
    <div className="flex gap-3 justify-start animate-fade-in">
      <div className="flex-shrink-0 w-8 h-8 rounded-full bg-primary-subtle flex items-center justify-center mt-1">
        <Bot className="w-4 h-4 text-primary" />
      </div>
      <div className="bg-assistant-bubble rounded-2xl rounded-bl-md px-5 py-4">
        <div className="flex items-center gap-1.5">
          <span
            className="w-2 h-2 rounded-full bg-text-tertiary animate-pulse-dot"
            style={{ animationDelay: "0ms" }}
          />
          <span
            className="w-2 h-2 rounded-full bg-text-tertiary animate-pulse-dot"
            style={{ animationDelay: "200ms" }}
          />
          <span
            className="w-2 h-2 rounded-full bg-text-tertiary animate-pulse-dot"
            style={{ animationDelay: "400ms" }}
          />
        </div>
      </div>
    </div>
  );
}

/**
 * Format a Date into a readable time string.
 */
function formatTimestamp(date: Date): string {
  const d = new Date(date);
  return d.toLocaleTimeString(undefined, {
    hour: "2-digit",
    minute: "2-digit",
  });
}
