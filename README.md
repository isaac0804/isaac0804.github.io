# Personal site local setup

This repository uses [Hugo](https://gohugo.io/), not Jekyll. The theme is `PaperMod`.

## First-time setup

Run this from the repository root:

```powershell
.\scripts\setup-hugo.ps1
```

That downloads a local copy of Hugo Extended into `.tools/hugo/`, so you do not need a global install.

## Start the site locally

```powershell
.\scripts\serve.ps1
```

The site will be available at `http://127.0.0.1:1313/`.

Draft posts are shown locally because the script runs `hugo server --buildDrafts`.

## Create a new post

```powershell
.\scripts\new-post.ps1 "My New Post"
```

That creates a new draft in `content/posts/` using today's date in the filename.

When you are ready to publish the post, change this line in the post front matter:

```yaml
draft: false
```

## Build the site

```powershell
.\.tools\hugo\hugo.exe
```

That regenerates the static output in `public/`.
