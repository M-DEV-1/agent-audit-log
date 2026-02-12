import './globals.css'
import type { PropsWithChildren } from 'react'

export const metadata = {
  title: 'Agent Audit Log',
  description: 'Trace viewer for the autonomous Colosseum agent'
}

export default function RootLayout({ children }: PropsWithChildren) {
  return (
    <html lang="en">
      <body>
        <div className="min-h-screen bg-slate-950 text-slate-50">
          <main className="max-w-4xl mx-auto px-4 py-10">{children}</main>
        </div>
      </body>
    </html>
  )
}
