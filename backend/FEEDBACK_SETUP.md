# ASTROML Suggestions / Issue Reports

The Flutter dialog is implemented in the app drawer. Feedback is sent through the Cloudflare Worker in this folder so the Telegram bot token is **not stored in the APK**.

## 1. Secure the bot token

The bot token was pasted into a chat. Treat it as compromised: open Telegram's **@BotFather**, revoke/regenerate that token, and use only the new token as a Cloudflare Worker secret. Do not put it in Dart code, GitHub source, or this repository.

## 2. Deploy the Worker

1. Install Wrangler and log in to Cloudflare.
2. From this `backend` folder, copy `wrangler.toml.example` to `wrangler.toml` and replace `REPLACE_WITH_YOUR_CHAT_ID` with your Telegram chat ID.
3. Run `npx wrangler secret put TELEGRAM_BOT_TOKEN` and paste the newly generated token into the terminal prompt.
4. Run `npx wrangler deploy`.
5. Copy the deployed HTTPS Worker URL into `FeedbackService.endpoint` in `lib/services/feedback_service.dart`.

## 3. App behavior

- Drawer > **Change Logs** opens the in-app release history dialog.
- Drawer > **Suggestions / Report** opens a dialog with Suggestion and Report issue types.
- The app sends the message with device, Android, chipset, manufacturer, model, and submission timestamp metadata.

The app cannot send feedback until the Worker is deployed and its URL is configured.
