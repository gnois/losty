--
-- Generated from home.lt
--
return function(data)
    local title = data.title or "@@APP_NAME@@"
    local user = data.user
    local nav
    if user then
        nav = string.format("<nav style=\"text-align:right;margin-bottom:16px\">Signed in as <strong>%s</strong> &middot; <a href=\"/app\">My account</a></nav>", user.username or "")
    else
        nav = "<nav style=\"text-align:right;margin-bottom:16px\"><a href=\"/signin\">Sign in</a> &middot; <a href=\"/signup\">Sign up</a></nav>"
    end
    return string.format([=[<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>%s</title>
  <style>
		body { font-family: sans-serif; max-width: 760px; margin: 60px auto; color: #333; line-height: 1.45; }
		.card { border: 1px solid #e4e4e4; border-radius: 8px; padding: 18px; background: #fff; }
		.actions a { display: inline-block; margin-right: 10px; }
  </style>
</head>
<body>
  %s
	<div class="card">
		<h1>%s</h1>
		<p>This is the public page for your generated Losty app.</p>
		<p>It is always accessible, and authenticated users can continue to their protected page.</p>
		<p class="actions">
			<a href="/app">Protected page</a>
		</p>
	</div>
</body>
</html>]=], title, nav, title)
end
