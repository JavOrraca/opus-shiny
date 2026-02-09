import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "AI SQL Chatbot",
  description:
    "Natural language to SQL chatbot - ask questions about your data in plain English",
  keywords: ["SQL", "chatbot", "AI", "natural language", "database", "query"],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body className="min-h-screen bg-background font-sans antialiased">
        {children}
      </body>
    </html>
  );
}
