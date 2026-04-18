--
-- Generated from auth.lt
--
local style = [=[
  <style>
    body { font-family: sans-serif; max-width: 420px; margin: 64px auto; color: #2a2a2a; line-height: 1.45; }
    h1 { margin: 0 0 6px; }
    p.muted { margin: 0 0 14px; color: #666; }
    label { display: block; margin-top: 14px; font-size: .92em; color: #555; }
    input[type=text], input[type=password] {
      width: 100%%; padding: 8px 10px; margin-top: 4px;
      box-sizing: border-box; border: 1px solid #ccc; border-radius: 4px;
    }
    button { margin-top: 20px; padding: 9px 22px; cursor: pointer; border: 1px solid #1254b0; background: #1d69d8; color: white; border-radius: 4px; }
    .err { color: #b00020; background: #fff4f6; border: 1px solid #f0c4cc; border-radius: 4px; padding: 8px 10px; margin-top: 12px; font-size: .92em; }
    a { color: #175bc2; text-decoration: none; }
    a:hover { text-decoration: underline; }
    .foot { margin-top: 16px; }
  </style>]=]
local signup_tmpl = [=[<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>%s</title>%s
</head>
<body>
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
  <title>%s</title>%s
</head>
<body>
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
    return string.format(signup_tmpl, data.title or "Sign up", style, err_html(data.error), data.csrf_token or "")
end, signin = function(data)
    return string.format(signin_tmpl, data.title or "Sign in", style, err_html(data.error), data.csrf_token or "")
end}
