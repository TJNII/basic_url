all: test lint

build: test lint
	./cicd/build_gem.sh

lint:
	bundle exec rubocop

push:
	./cicd/push_gem.sh

test:
	bundle exec rspec

