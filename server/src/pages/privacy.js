// The privacy policy, served at /privacy (the link for the Play Store listing).
// Keep it in step with mobile/lib/features/privacy/privacy_screen.dart.
const config = require('../config');

const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function privacyHtml() {
  const contact = process.env.PRIVACY_CONTACT
    ? `<a href="mailto:${esc(process.env.PRIVACY_CONTACT)}">${esc(process.env.PRIVACY_CONTACT)}</a>`
    : 'the developer email shown on the app\'s Google Play page';
  const stored = config.mongoUri
    ? `<p>This server also keeps a small profile per player ID: the player name and how many games were played and won,
       so stats can be shown. It holds nothing else. To have it removed, contact us with the name you played under.</p>`
    : '<p>The server does not save anything to a database: a room and everything in it is gone from memory when the room ends.</p>';
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Party Games: Privacy Policy</title>
<style>
  body { font: 16px/1.6 system-ui, -apple-system, Segoe UI, Roboto, sans-serif; margin: 0; background: #f4f7fb; color: #22212b; }
  main { max-width: 720px; margin: 0 auto; padding: 28px 20px 48px; }
  h1 { font-size: 28px; margin: 0 0 4px; } h2 { font-size: 19px; margin: 28px 0 6px; }
  .date { color: #6b7280; margin: 0 0 20px; } ul { padding-left: 22px; } a { color: #2563eb; }
  .box { background: #fff; border-radius: 14px; padding: 4px 18px; box-shadow: 0 1px 3px #0001; }
</style></head>
<body><main>
<h1>Privacy Policy</h1>
<p class="date">Party Games and Party Games Flat · Effective 3 October 2026</p>
<div class="box">
<h2>In short</h2>
<p>No account, no email, no ads, no tracking. You only type a player name. Games on one phone never leave that phone.</p>

<h2>What we collect</h2>
<ul>
  <li><b>Your player name</b>: the name you type when you start. Other players in your room see it.</li>
  <li><b>A random player ID</b>: made on your phone (it isn't linked to you, your phone number or your Google account) so you can rejoin a room after a short disconnect.</li>
  <li><b>Game moves</b>: when you play online, your moves (and drawings in Draw &amp; Guess) are sent through our server to the other players in your room.</li>
</ul>
<p>We do <b>not</b> collect your email, phone number, contacts, location, photos, camera, microphone, or advertising ID.
The app has no ads and no analytics.</p>

<h2>Where it is kept</h2>
<p>Your name and player ID are saved on your phone so you don't have to type them again.</p>
${stored}
<p>Like any website, the hosting provider may briefly keep technical logs (such as IP addresses) to run and protect the service.</p>

<h2>Who we share it with</h2>
<p>Only the other players in your room see your name and moves. We do not sell or share data with anyone else.</p>

<h2>Deleting your data</h2>
<p>In the app, open <b>Home &gt; Privacy</b> and tap <b>Delete my data on this phone</b>, or uninstall the app.
That removes your name and player ID from the phone.</p>

<h2>Children</h2>
<p>The app is a party game for teenagers and adults and is not directed at children under 13.
Some party games (like Truth or Dare) are meant for groups of friends.</p>

<h2>Changes and contact</h2>
<p>If this policy changes, the new version will be posted on this page with a new date.
Questions: contact ${contact}.</p>
</div>
</main></body></html>`;
}

module.exports = { privacyHtml };
