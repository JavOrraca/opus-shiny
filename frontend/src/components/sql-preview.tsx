"use client";

import { useState, useCallback } from "react";
import { Prism as SyntaxHighlighter } from "react-syntax-highlighter";
import { vscDarkPlus } from "react-syntax-highlighter/dist/esm/styles/prism";
import { Copy, Check, ChevronDown, ChevronRight, Code2 } from "lucide-react";

interface SqlPreviewProps {
  sql: string;
  defaultExpanded?: boolean;
}

export function SqlPreview({ sql, defaultExpanded = true }: SqlPreviewProps) {
  const [isExpanded, setIsExpanded] = useState(defaultExpanded);
  const [isCopied, setIsCopied] = useState(false);

  const sqlString = typeof sql === "string" ? sql : String(sql ?? "");

  const handleCopy = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(sqlString);
      setIsCopied(true);
      setTimeout(() => setIsCopied(false), 2000);
    } catch {
      // Fallback for older browsers
      const textarea = document.createElement("textarea");
      textarea.value = sqlString;
      textarea.style.position = "fixed";
      textarea.style.opacity = "0";
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand("copy");
      document.body.removeChild(textarea);
      setIsCopied(true);
      setTimeout(() => setIsCopied(false), 2000);
    }
  }, [sqlString]);

  const formattedSql = sqlString.trim();

  return (
    <div className="mt-3 rounded-lg border border-border overflow-hidden bg-code-bg">
      {/* Header */}
      <div className="flex items-center justify-between px-3 py-2 bg-code-header border-b border-border">
        <button
          onClick={() => setIsExpanded(!isExpanded)}
          className="flex items-center gap-2 text-xs font-medium text-text-secondary hover:text-text-primary transition-colors"
        >
          {isExpanded ? (
            <ChevronDown className="w-3.5 h-3.5" />
          ) : (
            <ChevronRight className="w-3.5 h-3.5" />
          )}
          <Code2 className="w-3.5 h-3.5" />
          <span>Generated SQL</span>
        </button>

        <button
          onClick={handleCopy}
          className="flex items-center gap-1.5 text-xs text-text-tertiary hover:text-text-primary transition-colors px-2 py-1 rounded hover:bg-surface-hover"
          title="Copy SQL to clipboard"
        >
          {isCopied ? (
            <>
              <Check className="w-3.5 h-3.5 text-success" />
              <span className="text-success">Copied</span>
            </>
          ) : (
            <>
              <Copy className="w-3.5 h-3.5" />
              <span>Copy</span>
            </>
          )}
        </button>
      </div>

      {/* Code Block */}
      {isExpanded && (
        <div className="animate-fade-in">
          <SyntaxHighlighter
            language="sql"
            style={vscDarkPlus}
            customStyle={{
              margin: 0,
              padding: "16px",
              background: "transparent",
              fontSize: "13px",
              lineHeight: "1.6",
            }}
            codeTagProps={{
              style: {
                fontFamily:
                  'var(--font-mono, "JetBrains Mono", "Fira Code", monospace)',
              },
            }}
            showLineNumbers={formattedSql.split("\n").length > 3}
            lineNumberStyle={{
              color: "#475569",
              fontSize: "11px",
              paddingRight: "16px",
              minWidth: "2em",
            }}
            wrapLongLines
          >
            {formattedSql}
          </SyntaxHighlighter>
        </div>
      )}
    </div>
  );
}
