# Repository Guidelines

## Project Structure & Module Organization
This repository is a community Ruby implementation of the Agent Client Protocol (ACP).

- `lib/agent_client_protocol/`: core runtime code (RPC, codec, decoder, validator, type registry, generated type base classes).
- `lib/agent_client_protocol.rb`: top-level entrypoint and public API helpers.
- `test/`: Minitest suite (`*_test.rb`) covering codec, validator, decoder, types, RPC, and protocol version behavior.
- `schema/`: vendored ACP schema and metadata (`schema.json`, `schema.unstable.json`, `meta*.json`).
- `scripts/sync_schema.sh`: syncs schema files from an upstream ACP checkout.

## Build, Test, and Development Commands
- `bundle install`: install gem dependencies.
- `bundle exec rake test`: run the full test suite.
- `ruby -Ilib:test test/codec_test.rb`: run a single test file quickly.
- `./scripts/sync_schema.sh ../agent-client-protocol/schema`: refresh local schema from upstream.

## Coding Style & Naming Conventions
- Ruby 3.1+ style with `# frozen_string_literal: true` at file top.
- Use 2-space indentation; keep methods focused and small.
- Module/class names use `CamelCase` under `AgentClientProtocol`.
- File names use `snake_case` matching constants (for example `protocol_version.rb`, `type_registry.rb`).
- Prefer explicit, schema-driven behavior over ad-hoc conversions.

## Testing Guidelines
- Framework: Minitest (`test/test_helper.rb`).
- Name tests as `test/<feature>_test.rb` and methods as `test_<behavior>`.
- Add/adjust tests for every behavior change, especially:
  - method routing by side (`agent`, `client`, `protocol`),
  - schema validation errors and paths,
  - stable vs unstable schema compatibility.
- Keep assertions specific (error code, path, typed class, and payload shape).

## Commit & Pull Request Guidelines
- Commit messages should be imperative and concise (example: `Add protocol-level notification decode support`).
- Keep commits scoped to one logical change.
- PRs should include:
  - summary of behavior changes,
  - impacted files/modules,
  - test evidence (`bundle exec rake test` output),
  - schema/version notes if `schema/` changed.

## Security & Configuration Tips
- Do not commit secrets or tokens.
- Treat vendored `schema/` files as authoritative protocol input; avoid manual edits unless intentionally patching with rationale in PR.
