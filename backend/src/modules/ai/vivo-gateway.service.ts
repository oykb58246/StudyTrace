import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac, randomBytes, randomUUID } from 'crypto';

export type VivoCapabilityTrace = {
  abilityName: string;
  endpoint: string;
  model?: string;
  success: boolean;
  fallback?: string;
  durationMs: number;
  requestId: string;
  detail?: string;
};

@Injectable()
export class VivoGatewayService {
  constructor(private readonly config: ConfigService) {}

  trace(
    abilityName: string,
    endpoint: string,
    requestId: string,
    startedAt: number,
    success: boolean,
    options: { model?: string; fallback?: string; detail?: string } = {},
  ): VivoCapabilityTrace {
    return {
      abilityName,
      endpoint,
      requestId,
      success,
      durationMs: Date.now() - startedAt,
      ...options,
    };
  }

  async postJson(path: string, body: Record<string, unknown>) {
    return this.requestJson('POST', path, {}, body, 'application/json');
  }

  async postForm(path: string, body: URLSearchParams) {
    return this.requestJson('POST', path, {}, body, 'application/x-www-form-urlencoded');
  }

  async getJson(path: string, query: Record<string, string> = {}) {
    return this.requestJson('GET', path, query);
  }

  async optionalPostJson(urlEnv: string, body: Record<string, unknown>) {
    const endpoint = this.config.get<string>(urlEnv);
    if (!endpoint) {
      throw new ServiceUnavailableException(`${urlEnv} is not configured`);
    }
    return this.requestJson('POST', endpoint, {}, body);
  }

  async optionalPostForm(urlEnv: string, body: URLSearchParams) {
    const endpoint = this.config.get<string>(urlEnv);
    if (!endpoint) {
      throw new ServiceUnavailableException(`${urlEnv} is not configured`);
    }
    return this.requestJson('POST', endpoint, {}, body, 'application/x-www-form-urlencoded');
  }

  private async requestJson(
    method: 'GET' | 'POST',
    path: string,
    query: Record<string, string> = {},
    body?: Record<string, unknown> | URLSearchParams,
    contentType = 'application/json',
  ) {
    const baseUrl = this.config.get<string>('VIVO_GATEWAY_BASE_URL') ?? 'https://api-ai.vivo.com.cn';
    const url = new URL(path, baseUrl);
    for (const [key, value] of Object.entries(query)) {
      url.searchParams.set(key, value);
    }
    const params = Object.fromEntries(url.searchParams);
    const headers = this.signHeaders(method, url.pathname, params);
    if (body) headers['Content-Type'] = contentType;
    const response = await fetch(url.toString(), {
      method,
      headers,
      body:
        body instanceof URLSearchParams
          ? body
          : body
            ? JSON.stringify(body)
            : undefined,
    });
    const raw = await response.text();
    if (!response.ok) throw new Error(raw);
    try {
      return raw ? JSON.parse(raw) : {};
    } catch (_) {
      return { raw };
    }
  }

  private signHeaders(method: string, uri: string, query: Record<string, string>) {
    const appId = this.required('BLUEHEART_APP_ID');
    const appKey = this.required('BLUEHEART_API_KEY');
    const timestamp = Math.floor(Date.now() / 1000).toString();
    const nonce = randomBytes(4).toString('hex');
    const signedHeaders = 'x-ai-gateway-app-id;x-ai-gateway-timestamp;x-ai-gateway-nonce';
    const canonicalQuery = Object.entries(query)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([key, value]) => `${encodeURIComponent(key)}=${encodeURIComponent(value ?? '')}`)
      .join('&');
    const signedHeaderString = [
      `x-ai-gateway-app-id:${appId}`,
      `x-ai-gateway-timestamp:${timestamp}`,
      `x-ai-gateway-nonce:${nonce}`,
    ].join('\n');
    const signingString = [
      method,
      uri.startsWith('/') ? uri : `/${uri}`,
      canonicalQuery,
      appId,
      timestamp,
      signedHeaderString,
    ].join('\n');
    const signature = createHmac('sha256', appKey).update(signingString).digest('base64');
    return {
      'X-AI-GATEWAY-APP-ID': appId,
      'X-AI-GATEWAY-TIMESTAMP': timestamp,
      'X-AI-GATEWAY-NONCE': nonce,
      'X-AI-GATEWAY-SIGNED-HEADERS': signedHeaders,
      'X-AI-GATEWAY-SIGNATURE': signature,
    } as Record<string, string>;
  }

  requestId() {
    return randomUUID();
  }

  private required(key: string) {
    const value = this.config.get<string>(key);
    if (!value) throw new ServiceUnavailableException(`${key} is not configured`);
    return value;
  }
}
