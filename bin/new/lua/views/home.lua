--
-- Generated from home.lt
--
return function(data)
    local title = data.title or "@@APP_NAME@@"
    local user = data.user
    local nav
    if user then
        nav = string.format("<nav class=\"topnav\">Signed in as <strong>%s</strong> &middot; <a href=\"/app\">My account</a></nav>", user.username or "")
    else
        nav = "<nav class=\"topnav\"><a href=\"/signin\">Sign in</a> &middot; <a href=\"/signup\">Sign up</a></nav>"
    end
    return string.format([=[<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>%s</title>
	<link rel="stylesheet" href="/public/0/style.css">
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
