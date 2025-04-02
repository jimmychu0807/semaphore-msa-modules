import type { Metadata, Viewport } from "next";
import { headers } from "next/headers";
import { Geist, Geist_Mono } from "next/font/google";
import { cookieToInitialState } from "wagmi";

import { getConfig } from "@/utils";
import { Providers } from "@/components/Providers";
import { Toaster } from "@/components/ui/sonner";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Anonymous multi-sig wallet with Semaphore Modules",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const initialState = cookieToInitialState(getConfig(), (await headers()).get("cookie"));

  return (
    <html lang="en" suppressHydrationWarning>
      <body className={`${geistSans.variable} ${geistMono.variable} antialiased`}>
        <Providers initialState={initialState}>
          <div className="flex flex-row items-start justify-center min-h-screen gap-12 px-8 md:px-[0] font-[family-name:var(--font-geist-sans)]">
            <main className="flex flex-col gap-8 mt-8 items-center sm:items-start">{children}</main>
          </div>
          <Toaster richColors closeButton={true} />
        </Providers>
      </body>
    </html>
  );
}
