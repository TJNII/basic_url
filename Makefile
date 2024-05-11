all: test lint

lint:
	bundle exec rubocop

test:
	bundle exec rspec

push: test lint
