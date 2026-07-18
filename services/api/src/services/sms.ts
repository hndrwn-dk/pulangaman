import { config } from '../config.js';

export async function sendSms(
  phone: string,
  message: string,
): Promise<{ ok: boolean; provider: string }> {
  if (config.SMS_PROVIDER === 'http' && config.SMS_HTTP_URL) {
    const response = await fetch(config.SMS_HTTP_URL, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        ...(config.SMS_HTTP_TOKEN
          ? { authorization: `Bearer ${config.SMS_HTTP_TOKEN}` }
          : {}),
      },
      body: JSON.stringify({ phone, message }),
    });
    if (!response.ok) {
      const text = await response.text();
      console.error('sms_http_failed', { status: response.status, text });
      return { ok: false, provider: 'http' };
    }
    return { ok: true, provider: 'http' };
  }

  console.info('sms_console_stub', { phone, message });
  return { ok: true, provider: 'console' };
}
