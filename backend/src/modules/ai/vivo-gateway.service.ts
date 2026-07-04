import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'crypto';

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

  async postJson(
    path: string,
    body: Record<string, unknown>,
    query: Record<string, string> = {},
  ) {
    return this.requestJson('POST', path, query, body, 'application/json');
  }

  async postForm(
    path: string,
    body: URLSearchParams,
    query: Record<string, string> = {},
  ) {
    return this.requestJson('POST', path, query, body, 'application/x-www-form-urlencoded');
  }

  async postMultipart(
    path: string,
    body: FormData,
    query: Record<string, string> = {},
  ) {
    return this.requestJson('POST', path, query, body);
  }

  async getJson(path: string, query: Record<string, string> = {}) {
    return this.requestJson('GET', path, query);
  }

  async optionalPostJson(
    urlEnv: string,
    body: Record<string, unknown>,
    query: Record<string, string> = {},
  ) {
    const endpoint = this.config.get<string>(urlEnv);
    if (!endpoint) {
      throw new ServiceUnavailableException(`${urlEnv} is not configured`);
    }
    return this.requestJson('POST', endpoint, query, body);
  }

  async optionalPostForm(
    urlEnv: string,
    body: URLSearchParams,
    query: Record<string, string> = {},
  ) {
    const endpoint = this.config.get<string>(urlEnv);
    if (!endpoint) {
      throw new ServiceUnavailableException(`${urlEnv} is not configured`);
    }
    return this.requestJson('POST', endpoint, query, body, 'application/x-www-form-urlencoded');
  }

  private async requestJson(
    method: 'GET' | 'POST',
    path: string,
    query: Record<string, string> = {},
    body?: Record<string, unknown> | URLSearchParams | FormData,
    contentType = 'application/json',
  ) {
    const baseUrl = this.config.get<string>('VIVO_GATEWAY_BASE_URL') ?? 'https://api-ai.vivo.com.cn';
    const url = new URL(path, baseUrl);
    for (const [key, value] of Object.entries(query)) {
      url.searchParams.set(key, value);
    }
    const headers = this.authHeaders();
    if (body && !(body instanceof FormData)) headers['Content-Type'] = contentType;
    const response = await fetch(url.toString(), {
      method,
      headers,
      body:
        body instanceof URLSearchParams || body instanceof FormData
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

  private authHeaders() {
    return {
      Authorization: `Bearer ${this.required('BLUEHEART_API_KEY')}`,
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
