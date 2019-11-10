# docker-hexo

My docerized utilization of [Hexo](https://github.com/hexojs/hexo) to note, blog, and publish.
Applied the [jane theme](https://github.com/hejianxian/hexo-theme-jane).

## Prerequisite

- Docker Engine
- Github SSH Setup
    - Set to `${HOME}/.ssh/github_rsa` for example

## Usage

- Image build.

```
$ make build
```

- Start a local server. Then a local server would serve in `http://localhost:4000`.

```
$ make start
```

- Create new post.

```
$ make post POST="[POST_TITLE]"
```

- Publish to `github.io`.

```
$ make publish
```
