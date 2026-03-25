# IntaSend Webhook Events

## Endpoint
Supabase Edge Function: `supabase/functions/handle-payment/index.ts`

## Events Handled

| Event | Description | Action |
|-------|-------------|--------|
| `COMPLETE` | Payment successful | Update transaction status, credit account |
| `FAILED` | Payment failed | Update transaction status to failed |
| `PENDING` | Payment pending | Keep status as pending |

## Payload Example (STK Push)
```json
{
  "invoice_id": "XXXXX",
  "state": "COMPLETE",
  "provider": "M-PESA",
  "charges": "0.00",
  "net_amount": 1000.00,
  "currency": "KES",
  "value": "1000.00",
  "account": "254XXXXXXXXX",
  "api_ref": "member_id:account_type:transaction_id"
}
```

## Security
- Verify webhook signature using `INTASEND_WEBHOOK_SECRET` env var
- All webhook processing happens server-side in edge functions only
