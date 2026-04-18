--
-- Generated from protected.lt
--
return function(data)
    local title = data.title or "@@APP_NAME@@ — Account"
    local user = data.user or {}
    return string.format([=[<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>%s</title>
  <style>
    body { font-family: sans-serif; max-width: 760px; margin: 60px auto; color: #333; line-height: 1.45; }
    .card { border: 1px solid #e4e4e4; border-radius: 8px; padding: 18px; background: #fff; }
    .topnav { text-align: right; margin-bottom: 16px; }
    button { padding: 8px 18px; border: 1px solid #1254b0; background: #1d69d8; color: #fff; border-radius: 4px; cursor: pointer; }
  </style>
  <script>
    window.addEventListener('pageshow', function (evt) {
      var nav = (window.performance && performance.getEntriesByType) ? performance.getEntriesByType('navigation') : null;
      if (evt.persisted || (nav && nav[0] && nav[0].type === 'back_forward')) {
        window.location.reload();
      }
    });
  </script>
</head>
<body>
  <div class="topnav"><a href="/">Public page</a></div>
  <div class="card">
    <h1>%s</h1>
    <p>You are signed in as <strong>%s</strong>.</p>
    <p>This page is protected and requires an active session.</p>
    <form method="POST" action="/signout">
      <input type="hidden" name="token" value="%s">
      <button type="submit">Sign out</button>
    </form>
  </div>
</body>
</html>]=], title, title, user.username or "", data.csrf_token or "")
end
