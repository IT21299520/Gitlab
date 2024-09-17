# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillProtectedEnvironmentApprovalRulesProtectedEnvironmentProjectId,
  feature_category: :continuous_delivery,
  schema: 20240814104150 do
  include_examples 'desired sharding key backfill job' do
    let(:batch_table) { :protected_environment_approval_rules }
    let(:backfill_column) { :protected_environment_project_id }
    let(:backfill_via_table) { :protected_environments }
    let(:backfill_via_column) { :project_id }
    let(:backfill_via_foreign_key) { :protected_environment_id }
  end
end
