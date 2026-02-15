# frozen_string_literal: true

require_relative "test_helper"

class ConstantsTest < Minitest::Test
  def test_tool_kind_constants
    assert_equal "read", AgentClientProtocol::ToolKind::READ
    assert_equal "edit", AgentClientProtocol::ToolKind::EDIT
    assert_equal "execute", AgentClientProtocol::ToolKind::EXECUTE
    assert_equal "think", AgentClientProtocol::ToolKind::THINK
    assert_equal "other", AgentClientProtocol::ToolKind::OTHER
  end

  def test_tool_call_status_constants
    assert_equal "pending", AgentClientProtocol::ToolCallStatus::PENDING
    assert_equal "in_progress", AgentClientProtocol::ToolCallStatus::IN_PROGRESS
    assert_equal "completed", AgentClientProtocol::ToolCallStatus::COMPLETED
    assert_equal "failed", AgentClientProtocol::ToolCallStatus::FAILED
  end

  def test_plan_entry_status_constants
    assert_equal "pending", AgentClientProtocol::PlanEntryStatus::PENDING
    assert_equal "in_progress", AgentClientProtocol::PlanEntryStatus::IN_PROGRESS
    assert_equal "completed", AgentClientProtocol::PlanEntryStatus::COMPLETED
  end

  def test_plan_entry_priority_constants
    assert_equal "high", AgentClientProtocol::PlanEntryPriority::HIGH
    assert_equal "medium", AgentClientProtocol::PlanEntryPriority::MEDIUM
    assert_equal "low", AgentClientProtocol::PlanEntryPriority::LOW
  end

  def test_role_constants
    assert_equal "assistant", AgentClientProtocol::Role::ASSISTANT
    assert_equal "user", AgentClientProtocol::Role::USER
  end

  def test_stop_reason_constants
    assert_equal "end_turn", AgentClientProtocol::StopReason::END_TURN
    assert_equal "max_tokens", AgentClientProtocol::StopReason::MAX_TOKENS
    assert_equal "cancelled", AgentClientProtocol::StopReason::CANCELLED
  end

  def test_permission_option_kind_constants
    assert_equal "allow_once", AgentClientProtocol::PermissionOptionKind::ALLOW_ONCE
    assert_equal "allow_always", AgentClientProtocol::PermissionOptionKind::ALLOW_ALWAYS
    assert_equal "reject_once", AgentClientProtocol::PermissionOptionKind::REJECT_ONCE
    assert_equal "reject_always", AgentClientProtocol::PermissionOptionKind::REJECT_ALWAYS
  end

  def test_error_code_module_not_overwritten
    # ErrorCode is hand-defined in error.rb and must not be replaced by constants
    assert_equal(-32_700, AgentClientProtocol::ErrorCode::PARSE_ERROR)
    assert AgentClientProtocol::ErrorCode.respond_to?(:default_message)
  end

  def test_constants_are_frozen
    assert AgentClientProtocol::ToolKind.frozen?
  end
end
