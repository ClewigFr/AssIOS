# Privacy: what Anonymous Simple Stats collects

Anonymous Simple Stats counts screen views. It is built so that nothing it collects identifies a person
or a device, but it does collect data: this page lists all of it.

## What the library sends

For each screen view, and nothing else:

| Field       | What it is | Who chooses it |
|-------------|------------|----------------|
| `app`       | The UUID of your application in the dashboard | You, in `AssConfig` |
| `page`      | The UUID of the screen in the dashboard | You, in `logScreen` / `trackScreen` |
| `sessionId` | A random UUID drawn at each app launch, kept in memory only | The library |
| `timestamp` | How many milliseconds ago the view happened | The library |

The library never reads or sends:
- a user, device or advertising identifier (no IDFA, no `identifierForVendor`, no install ID);
- the device model, OS version, language, location, app version, or anything about the user's content;
- cookies: requests use an ephemeral session, without cookies or cache, and a neutral `User-Agent`.

Two launches can't be linked: the session id is never written to disk. It doesn't use App Tracking
Transparency, and doesn't need to ask for it.

## What stays on the device

Views not sent yet: in memory, and in the app's Caches directory when an upload failed or the app went to the
background (`Library/Caches/AnonymousSimpleStats/retry.json`). That file holds the same four fields, at most
1000 views and none older than 7 days, and is deleted once they are delivered. It isn't backed up.

## What the server keeps

Data sent to the hosted service (`ass-api.clewig.fr`), or to a self-hosted backend under its own settings:
- The views, as sent, for 90 days by default (`RETENTION_DAYS`). After that only the number of views per page
  and per day is kept: the session ids are deleted.
- The device's IP address reaches the server with each request, as with any network connection. It is only used
  in memory, to limit abuse, and is never stored or logged.

The hosted service's privacy policy, with its processors, is at https://ass.clewig.fr/#/privacy.

## App Store privacy details

The package ships a privacy manifest (`Sources/AnonymousSimpleStats/PrivacyInfo.xcprivacy`) that declares:
- **Product Interaction**, used for **Analytics**;
- **not linked** to the user's identity;
- **not used for tracking**, with no tracking domains.

Declare the same in App Store Connect for your app. As the developer of the app, you remain responsible for
informing its users, for example in your own privacy policy.
