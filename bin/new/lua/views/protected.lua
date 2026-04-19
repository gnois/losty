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
  <link rel="stylesheet" href="/public/5/style.css">
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
