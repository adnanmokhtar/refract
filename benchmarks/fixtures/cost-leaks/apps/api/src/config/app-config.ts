import { Injectable } from '@nestjs/common';
import { Env, envSchema } from './env.schema';

@Injectable()
export class AppConfig {
  private readonly env: Env = envSchema.parse(process.env);

  get region() { return this.env.AWS_REGION; }
  get s3Endpoint() { return this.env.S3_ENDPOINT; }
  get exportsBucket() { return this.env.EXPORTS_BUCKET; }
  get importsBucket() { return this.env.IMPORTS_BUCKET; }
  get mediaBucket() { return this.env.MEDIA_BUCKET; }
  get reportsBucket() { return this.env.REPORTS_BUCKET; }
  get labelArchiveBucket() { return this.env.LABEL_ARCHIVE_BUCKET; }
  get publicMediaBaseUrl() { return this.env.PUBLIC_MEDIA_BASE_URL; }
  get labelQueueUrl() { return this.env.LABEL_QUEUE_URL; }
  get statusQueueUrl() { return this.env.STATUS_QUEUE_URL; }
  get llmGatewayUrl() { return this.env.LLM_GATEWAY_URL; }
  get llmGatewayKey() { return this.env.LLM_GATEWAY_KEY; }
  get llmModel() { return this.env.LLM_MODEL; }
  get carrierApiBaseUrl() { return this.env.CARRIER_API_BASE_URL; }
  get carrierApiKey() { return this.env.CARRIER_API_KEY; }
  get geocoderApiUrl() { return this.env.GEOCODER_API_URL; }
  get geocoderApiKey() { return this.env.GEOCODER_API_KEY; }
  get twilio() {
    return {
      accountSid: this.env.TWILIO_ACCOUNT_SID,
      authToken: this.env.TWILIO_AUTH_TOKEN,
      messagingServiceSid: this.env.TWILIO_MESSAGING_SERVICE_SID,
    };
  }
  get monthlyCaps() {
    return {
      sms: this.env.SMS_MONTHLY_CAP,
      carrier: this.env.CARRIER_MONTHLY_CALL_CAP,
      geocoder: this.env.GEOCODER_MONTHLY_CAP,
    };
  }
  get labelRendererUrl() { return this.env.LABEL_RENDERER_URL; }
  get publicOrigin() { return this.env.PUBLIC_ORIGIN; }
}
