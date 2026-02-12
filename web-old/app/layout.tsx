import './globals.css'
import type { PropsWithChildren } from 'react'

export const metadata = {
  title: 'Agent Audit Log',
  description: 'Trace viewer for the autonomous Colosseum agent'
}

export default function RootLayout({ children }: PropsWithChildren) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-slate-950 text-slate-100">
        <div className="relative">
          <div className="mx-auto max-w-6xl px-4 py-10 sm:px-6 lg:px-8">
            {children}
          </div>
        </div>
      </body>
    </html>
  )
}
