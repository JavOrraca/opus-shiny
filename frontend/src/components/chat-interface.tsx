"use client";

import { useState, useRef, useEffect, useCallback, type KeyboardEvent } from "react";
import {
  Send,
  Database,
  Trash2,
  Sparkles,
  MessageSquare,
  ArrowDown,
} from "lucide-react";
import { useChat } from "@/hooks/use-chat";
import { MessageBubble } from "@/components/message-bubble";

const SUGGESTED_QUERIES = [
  {
    label: "Show all tables",
    query: "What tables are available in the database?",
  },
  {
    label: "Row counts",
    query: "Show me the row count for each table",
  },
  {
    label: "Sample data",
    query: "Show me a sample of 5 rows from the most important table",
  },
  {
    label: "Column details",
    query: "Describe the columns and data types across all tables",
  },
];

export function ChatInterface() {
  const { messages, isLoading, sendMessage, clearMessages } = useChat();
  const [input, setInput] = useState("");
  const [showScrollButton, setShowScrollButton] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const messagesContainerRef = useRef<HTMLDivElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  // Auto-scroll to bottom on new messages
  const scrollToBottom = useCallback((behavior: ScrollBehavior = "smooth") => {
    messagesEndRef.current?.scrollIntoView({ behavior });
  }, []);

  useEffect(() => {
    scrollToBottom();
  }, [messages, scrollToBottom]);

  // Detect if user has scrolled up
  const handleScroll = useCallback(() => {
    const container = messagesContainerRef.current;
    if (!container) return;
    const threshold = 100;
    const isNearBottom =
      container.scrollHeight - container.scrollTop - container.clientHeight <
      threshold;
    setShowScrollButton(!isNearBottom);
  }, []);

  // Handle send message
  const handleSend = useCallback(async () => {
    const trimmed = input.trim();
    if (!trimmed || isLoading) return;
    setInput("");
    // Reset textarea height
    if (textareaRef.current) {
      textareaRef.current.style.height = "auto";
    }
    await sendMessage(trimmed);
  }, [input, isLoading, sendMessage]);

  // Handle keyboard shortcuts
  const handleKeyDown = useCallback(
    (e: KeyboardEvent<HTMLTextAreaElement>) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        handleSend();
      }
    },
    [handleSend]
  );

  // Auto-resize textarea
  const handleInputChange = useCallback(
    (e: React.ChangeEvent<HTMLTextAreaElement>) => {
      setInput(e.target.value);
      const textarea = e.target;
      textarea.style.height = "auto";
      textarea.style.height = `${Math.min(textarea.scrollHeight, 200)}px`;
    },
    []
  );

  // Handle suggested query click
  const handleSuggestedQuery = useCallback(
    (query: string) => {
      sendMessage(query);
    },
    [sendMessage]
  );

  const isEmpty = messages.length === 0;

  return (
    <div className="flex flex-col h-screen bg-background">
      {/* ===== Header ===== */}
      <header className="flex-shrink-0 border-b border-border bg-surface/80 backdrop-blur-xl sticky top-0 z-20">
        <div className="max-w-4xl mx-auto w-full px-4 h-14 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center">
              <Database className="w-4 h-4 text-primary" />
            </div>
            <div>
              <h1 className="text-sm font-semibold text-text-primary leading-none">
                AI SQL Chatbot
              </h1>
              <p className="text-[11px] text-text-tertiary mt-0.5">
                Natural language to SQL
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            {messages.length > 0 && (
              <button
                onClick={clearMessages}
                className="flex items-center gap-1.5 text-xs text-text-tertiary hover:text-text-secondary transition-colors px-2.5 py-1.5 rounded-lg hover:bg-surface-hover"
                title="Clear conversation"
              >
                <Trash2 className="w-3.5 h-3.5" />
                <span className="hidden sm:inline">Clear</span>
              </button>
            )}
          </div>
        </div>
      </header>

      {/* ===== Messages Area ===== */}
      <div
        ref={messagesContainerRef}
        onScroll={handleScroll}
        className="flex-1 overflow-y-auto"
      >
        <div className="max-w-4xl mx-auto w-full px-4 py-6">
          {isEmpty ? (
            <WelcomeScreen onSuggestedQuery={handleSuggestedQuery} />
          ) : (
            <div className="space-y-6">
              {messages.map((message) => (
                <MessageBubble key={message.id} message={message} />
              ))}
              <div ref={messagesEndRef} />
            </div>
          )}
        </div>
      </div>

      {/* Scroll-to-bottom button */}
      {showScrollButton && (
        <div className="absolute bottom-32 left-1/2 -translate-x-1/2 z-10">
          <button
            onClick={() => scrollToBottom()}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-surface-elevated border border-border shadow-lg text-xs text-text-secondary hover:text-text-primary hover:bg-surface-hover transition-all"
          >
            <ArrowDown className="w-3.5 h-3.5" />
            New messages
          </button>
        </div>
      )}

      {/* ===== Input Area ===== */}
      <div className="flex-shrink-0 border-t border-border bg-surface/80 backdrop-blur-xl">
        <div className="max-w-4xl mx-auto w-full px-4 py-3">
          <div className="flex items-end gap-3 bg-surface-hover rounded-2xl border border-border focus-within:border-primary/50 focus-within:ring-1 focus-within:ring-primary/20 transition-all px-4 py-3">
            <textarea
              ref={textareaRef}
              value={input}
              onChange={handleInputChange}
              onKeyDown={handleKeyDown}
              placeholder="Ask a question about your data..."
              rows={1}
              disabled={isLoading}
              className="flex-1 bg-transparent text-sm text-text-primary placeholder:text-text-muted resize-none outline-none min-h-[24px] max-h-[200px] leading-relaxed disabled:opacity-50"
            />
            <button
              onClick={handleSend}
              disabled={!input.trim() || isLoading}
              className="flex-shrink-0 w-8 h-8 rounded-lg bg-primary hover:bg-primary-hover disabled:bg-surface-active disabled:cursor-not-allowed flex items-center justify-center transition-all duration-200 disabled:opacity-40"
              title="Send message"
            >
              <Send className="w-4 h-4 text-white" />
            </button>
          </div>

          <p className="text-[10px] text-text-muted text-center mt-2">
            Press Enter to send, Shift+Enter for a new line
          </p>
        </div>
      </div>
    </div>
  );
}

/**
 * Welcome screen shown when chat is empty.
 */
function WelcomeScreen({
  onSuggestedQuery,
}: {
  onSuggestedQuery: (query: string) => void;
}) {
  return (
    <div className="flex flex-col items-center justify-center min-h-[60vh] animate-slide-up">
      {/* Icon */}
      <div className="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center mb-6">
        <Sparkles className="w-8 h-8 text-primary" />
      </div>

      {/* Heading */}
      <h2 className="text-2xl font-bold text-text-primary mb-2">
        Ask your data anything
      </h2>
      <p className="text-sm text-text-secondary text-center max-w-md mb-8 leading-relaxed">
        I can translate your natural language questions into SQL queries, execute
        them against your database, and explain the results.
      </p>

      {/* Suggested queries */}
      <div className="w-full max-w-lg">
        <p className="text-xs font-medium text-text-tertiary uppercase tracking-wider mb-3 text-center">
          Try asking
        </p>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
          {SUGGESTED_QUERIES.map((suggestion) => (
            <button
              key={suggestion.label}
              onClick={() => onSuggestedQuery(suggestion.query)}
              className="group flex items-start gap-3 p-3 rounded-xl bg-surface hover:bg-surface-hover border border-border hover:border-border-hover transition-all text-left"
            >
              <MessageSquare className="w-4 h-4 text-primary mt-0.5 flex-shrink-0" />
              <div>
                <p className="text-sm font-medium text-text-primary group-hover:text-primary-hover transition-colors">
                  {suggestion.label}
                </p>
                <p className="text-xs text-text-tertiary mt-0.5 line-clamp-2">
                  {suggestion.query}
                </p>
              </div>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
