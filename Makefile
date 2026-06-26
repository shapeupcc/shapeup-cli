.PHONY: test check syntax sync-skill

test:
	@for f in test/*_test.rb; do ruby -Ilib -Itest "$$f" || exit 1; done

check: syntax test

# Resync the plugin's skill copy with the canonical (gem-shipped) one.
# The two are kept byte-identical; skill_drift_test.rb enforces it.
sync-skill:
	@cp skills/shapeup/SKILL.md .claude-plugin/skills/shapeup/SKILL.md
	@echo "Synced .claude-plugin/skills/shapeup/SKILL.md from skills/shapeup/SKILL.md"

syntax:
	@for f in lib/shapeup_cli.rb lib/shapeup_cli/*.rb lib/shapeup_cli/commands/*.rb; do \
		ruby -c "$$f" > /dev/null || exit 1; \
	done
	@echo "Syntax OK"
