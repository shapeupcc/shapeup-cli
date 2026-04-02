.PHONY: test check syntax

test:
	ruby -Ilib -Itest test/output_test.rb test/config_test.rb test/args_test.rb test/exit_codes_test.rb test/skill_drift_test.rb

check: syntax test

syntax:
	@for f in lib/shapeup_cli.rb lib/shapeup_cli/*.rb lib/shapeup_cli/commands/*.rb; do \
		ruby -c "$$f" > /dev/null || exit 1; \
	done
	@echo "Syntax OK"
