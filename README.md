# Agent Client Protocol Ruby

Ruby helpers for implementing the [Agent Client Protocol (ACP)](https://agentclientprotocol.com/).

> Community version (unofficial): this repository is not the official ACP Ruby SDK and is not maintained by the ACP core maintainers.

This project references the canonical ACP schema from `../agent-client-protocol` and provides:

- ACP method constants (stable + unstable)
- Protocol version parsing behavior compatible with ACP
- JSON-RPC 2.0 request/response/notification models
- Side-aware request/notification decoding by method name
- Generated typed model classes from ACP schema definitions
- Strict JSON Schema validation for ACP payloads
- End-to-end codec helpers for RPC parsing/encoding + typed decode
- Protocol-level notifications (e.g. `$/cancel_request`, unstable)
- Enum convenience constants (`ToolKind::READ`, `ToolCallStatus::COMPLETED`, etc.)

## Install

Add to your Gemfile:

```ruby
gem "agent-client-protocol", "~> 0.1"
```

For local development against the source checkout:

```ruby
gem "agent-client-protocol", path: "/path/to/agent-client-protocol-ruby"
```

## Quick Start

```ruby
require "agent_client_protocol"

decoder = AgentClientProtocol::Decoder.new(side: :agent)
decoded = decoder.decode_request(method: "initialize", params: {
  "protocolVersion" => 1,
  "clientCapabilities" => {}
})

puts decoded.schema_name
# => "InitializeRequest"
puts decoded.typed_payload.class
# => AgentClientProtocol::Types::InitializeRequest
```

Typed classes are available by schema definition name:

```ruby
klass = AgentClientProtocol.type_for("InitializeRequest")
payload = klass.build(protocol_version: 1, client_capabilities: {})
payload.protocol_version # => 1
payload.to_h             # => {"protocolVersion"=>1, "clientCapabilities"=>{}}
```

Referenced nested schema fields are also coerced to typed models (including scalar wrappers such as `ProtocolVersion`).
Legacy protocol version strings are accepted and coerced to version `0` (matching official ACP behavior).

### Enum Constants

Common enum values are available as Ruby constants:

```ruby
AgentClientProtocol::ToolKind::READ          # => "read"
AgentClientProtocol::ToolCallStatus::PENDING  # => "pending"
AgentClientProtocol::PlanEntryStatus::COMPLETED # => "completed"
AgentClientProtocol::StopReason::END_TURN     # => "end_turn"
AgentClientProtocol::Role::ASSISTANT          # => "assistant"
```

### Validation

Payloads are schema-validated during decode by default. You can also validate directly:

```ruby
AgentClientProtocol.validate("InitializeRequest", {
  "protocolVersion" => 1,
  "clientCapabilities" => {}
})
# => true
```

### Codec

Codec helpers provide end-to-end JSON-RPC message handling:

```ruby
codec = AgentClientProtocol.codec(side: :agent)
request = codec.encode_request(
  method: "initialize",
  id: "req-1",
  params: { "protocolVersion" => 1, "clientCapabilities" => {} }
)
decoded = codec.decode_rpc(request)
decoded.typed_payload.class # => AgentClientProtocol::Types::InitializeRequest
```

## Scope

This is a schema-driven Ruby runtime implementation. It dynamically generates one Ruby class per ACP schema definition at runtime.

### Optional / Undefined Fields

Some ACP types (especially unstable ones) distinguish between a field being absent (undefined), explicitly `null`, and having a value. In the official Rust SDK this is modeled as `MaybeUndefined<T>`.

In Ruby, absent keys in the underlying attribute Hash represent "undefined", `nil` values represent JSON `null`, and all other values represent present data. Use `key?` to distinguish absent from null:

```ruby
obj.key?(:title)  # false => undefined (field was not sent)
obj[:title]        # nil   => could be null OR absent; use key? to tell apart
```

## Syncing With Upstream Schema

```bash
./scripts/sync_schema.sh
```

You can also pass a custom source directory:

```bash
./scripts/sync_schema.sh /path/to/agent-client-protocol/schema
```
