# Copy To

A quick-and-dirty Heroku app to simulate running `git clone`, `git remote add`, and `git push` locally.

## Why?

Sometime you don't want to fork a repository, but use it as the starting point for something else. Think of the original repository like a template.

## Running locally

1. Add `GITHUB_CLIENT_SECRET` and `GITHUB_CLIENT_ID` to `.env`
2. `script/bootstrap`
3. `script/server`
