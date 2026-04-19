--
-- Generated from auth.lt
--
local signup_tmpl = [=[<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>%s</title>
  <link rel="stylesheet" href="/public/1/style.css">
</head>
<body class="auth-page">
  <h1>Create account</h1>
  <p class="muted">Create your @@APP_NAME@@ account.</p>%s
  <form method="POST" action="/signup">
    <input type="hidden" name="token" value="%s">
    <label>Username
      <input type="text" name="username" required autofocus autocomplete="username">
    </label>
    <label>Password
      <input type="password" name="password" required autocomplete="new-password">
    </label>
    <button type="submit">Sign up</button>
  </form>
  <p class="foot">Already have an account? <a href="/signin">Sign in</a></p>
</body>
</html>]=]
local signin_tmpl = [=[<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>%s</title>
  <link rel="stylesheet" href="/public/2/style.css">
</head>
<body class="auth-page">
  <h1>Sign in</h1>
  <p class="muted">Use your @@APP_NAME@@ credentials.</p>%s
  <form method="POST" action="/signin">
    <input type="hidden" name="token" value="%s">
    <label>Username
      <input type="text" name="username" required autofocus autocomplete="username">
    </label>
    <label>Password
      <input type="password" name="password" required autocomplete="current-password">
    </label>
    <button type="submit">Sign in</button>
  </form>
  <p class="foot">No account yet? <a href="/signup">Sign up</a></p>
</body>
</html>]=]
local err_html = function(msg)
    if msg and msg ~= "" then
        return string.format("\n  <p class=\"err\">%s</p>", msg)
    end
    return ""
end
return {signup = function(data)
    return string.format(signup_tmpl, data.title or "Sign up", err_html(data.error), data.csrf_token or "")
end, signin = function(data)
    return string.format(signin_tmpl, data.title or "Sign in", err_html(data.error), data.csrf_token or "")
end}
