"use client";

import { useState } from "react";
import { Table, ChevronDown, ChevronRight } from "lucide-react";
import type { QueryResult } from "@/types";

interface DataTableProps {
  data: QueryResult;
  defaultExpanded?: boolean;
}

export function DataTable({ data, defaultExpanded = true }: DataTableProps) {
  const [isExpanded, setIsExpanded] = useState(defaultExpanded);

  if (!data || !data.columns || data.columns.length === 0) {
    return (
      <div className="mt-3 rounded-lg border border-border bg-surface p-4">
        <p className="text-sm text-text-tertiary italic">
          Query executed successfully but returned no data.
        </p>
      </div>
    );
  }

  const displayRows = data.rows.slice(0, 100);
  const hasMoreRows = data.rows.length > 100;

  return (
    <div className="mt-3 rounded-lg border border-border overflow-hidden bg-surface">
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
          <Table className="w-3.5 h-3.5" />
          <span>
            Results ({data.rowCount} row{data.rowCount !== 1 ? "s" : ""})
          </span>
        </button>
      </div>

      {/* Table */}
      {isExpanded && (
        <div className="animate-fade-in overflow-x-auto max-h-80 overflow-y-auto">
          <table className="w-full text-sm">
            <thead className="sticky top-0 z-10">
              <tr className="bg-surface-active">
                {data.columns.map((column) => (
                  <th
                    key={column}
                    className="px-4 py-2.5 text-left text-xs font-semibold text-text-secondary uppercase tracking-wider whitespace-nowrap border-b border-border"
                  >
                    {column}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {displayRows.map((row, rowIndex) => (
                <tr
                  key={rowIndex}
                  className={`transition-colors hover:bg-surface-hover ${
                    rowIndex % 2 === 0 ? "bg-surface" : "bg-surface-elevated"
                  }`}
                >
                  {data.columns.map((column) => (
                    <td
                      key={`${rowIndex}-${column}`}
                      className="px-4 py-2 text-text-primary whitespace-nowrap font-mono text-xs"
                    >
                      {formatCellValue(row[column])}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>

          {hasMoreRows && (
            <div className="px-4 py-2.5 bg-surface-active border-t border-border">
              <p className="text-xs text-text-tertiary text-center">
                Showing first 100 of {data.rowCount} rows
              </p>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

/**
 * Format a cell value for display in the table.
 */
function formatCellValue(value: unknown): string {
  if (value === null || value === undefined) {
    return "\u2014"; // em-dash for null values
  }
  if (typeof value === "boolean") {
    return value ? "true" : "false";
  }
  if (typeof value === "number") {
    // Format large numbers with commas
    if (Number.isInteger(value) && Math.abs(value) >= 1000) {
      return value.toLocaleString();
    }
    // Format decimals to a reasonable precision
    if (!Number.isInteger(value)) {
      return Number(value.toFixed(4)).toString();
    }
    return value.toString();
  }
  if (typeof value === "object") {
    return JSON.stringify(value);
  }
  return String(value);
}
