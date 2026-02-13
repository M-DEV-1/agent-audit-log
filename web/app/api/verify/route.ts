import { NextRequest, NextResponse } from 'next/server';
import { promises as fs } from 'fs';
import path from 'path';
import crypto from 'crypto';

export async function POST(request: NextRequest) {
  try {
    const { input } = await request.json();

    if (!input || typeof input !== 'string') {
      return NextResponse.json(
        { success: false, error: 'Invalid input' },
        { status: 400 }
      );
    }

    const trimmed = input.trim();
    let traceData: any;

    // Try parsing as JSON first
    if (trimmed.startsWith('{')) {
      try {
        traceData = JSON.parse(trimmed);
      } catch {
        return NextResponse.json(
          { success: false, error: 'Invalid JSON format' },
          { status: 400 }
        );
      }
    } else {
      // Treat as commit SHA
      const traceDir = path.join(process.cwd(), '../.agent-trace');
      
      try {
        const files = await fs.readdir(traceDir);
        const matchingFile = files.find(f => f.startsWith(trimmed) && f.endsWith('.json'));
        
        if (!matchingFile) {
          return NextResponse.json(
            { success: false, error: 'Trace file not found for this commit SHA' },
            { status: 404 }
          );
        }

        const fileContent = await fs.readFile(
          path.join(traceDir, matchingFile),
          'utf-8'
        );
        traceData = JSON.parse(fileContent);
      } catch (error) {
        return NextResponse.json(
          { success: false, error: 'Failed to read trace file' },
          { status: 500 }
        );
      }
    }

    // Validate RFC 0.1.0 compliance
    if (traceData.version !== '1.0') {
      return NextResponse.json({
        success: false,
        error: `Invalid RFC version: ${traceData.version || 'missing'}`,
      });
    }

    if (!traceData.id || !traceData.vcs?.revision || !traceData.tool?.name) {
      return NextResponse.json({
        success: false,
        error: 'Missing required RFC fields (id, vcs.revision, or tool.name)',
      });
    }

    // Verify hash integrity
    const storedHash = traceData.metadata?.trace_hash;
    let hashVerified = false;

    if (storedHash) {
      const { trace_hash, trace_hash_scope, solana_anchor, ...metadataWithoutHash } = traceData.metadata || {};
      const cleanTrace = { ...traceData, metadata: metadataWithoutHash };
      const canonical = JSON.stringify(cleanTrace, Object.keys(cleanTrace).sort(), 0);
      const computedHash = crypto.createHash('sha256').update(canonical).digest('hex');
      hashVerified = computedHash === storedHash;

      if (!hashVerified) {
        return NextResponse.json({
          success: false,
          error: 'Hash integrity check failed',
        });
      }
    }

    // Extract data
    const result = {
      success: true,
      version: traceData.version,
      id: traceData.id,
      timestamp: traceData.timestamp,
      commit: traceData.vcs?.revision,
      tool: traceData.tool?.name,
      model: traceData.tool?.version,
      traceHash: storedHash,
      txHash: traceData.metadata?.solana_anchor?.tx_hash,
      explorer: traceData.metadata?.solana_anchor?.explorer,
      fileCount: traceData.files?.length || 0,
    };

    return NextResponse.json(result);
  } catch (error) {
    console.error('Verification error:', error);
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    );
  }
}
