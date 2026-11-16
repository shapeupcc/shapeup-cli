.PHONY: test check syntax lint

test:
	@for f in test/*_test.rb; do ruby -Ilib -Itest "$$f" || exit 1; done

check: syntax test

# Omakase style (matches the parent ShapeUp app). Needs the dev gem:
#   bundle install
lint:
	@bundle exec rubocop

syntax:
	@for f in lib/shapeup_cli.rb lib/shapeup_cli/*.rb lib/shapeup_cli/commands/*.rb; do \
		ruby -c "$$f" > /dev/null || exit 1; \
	done
	@echo "Syntax OK"
