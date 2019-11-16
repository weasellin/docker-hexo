build:
	docker build \
		-t hexo \
		.

stop:
	docker rm -f hexo || true

start:
	docker run -d \
		--name hexo \
		--volume ${PWD}/source:/blog/source \
		--volume ${HOME}/.ssh/github_rsa:/root/.ssh/id_rsa:ro \
		-p 4000:4000 \
		hexo

restart: build stop start

post:
	docker exec -it \
		hexo \
		hexo new "${POST}"

publish:
	docker exec -it \
		hexo \
		hexo deploy
