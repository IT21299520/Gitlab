# frozen_string_literal: true

RSpec.shared_examples 'cloneable and moveable work item' do
  it 'increases the target namespace work items count by 1' do
    expect do
      service.execute
    end.to change { target_namespace.work_items.count }.by(1)
  end

  it 'runs all widget callbacks' do
    create_service_params = {
      work_item: anything, target_work_item: anything, current_user: current_user, params: anything
    }

    cleanup_service_params = {
      work_item: anything, target_work_item: nil, current_user: current_user, params: anything
    }

    original_work_item.widgets.flat_map(&:sync_data_callback_class).each do |callback_class|
      allow_next_instance_of(callback_class, **create_service_params) do |callback_instance|
        expect(callback_instance).to receive(:before_create)
        expect(callback_instance).to receive(:after_save_commit)
      end

      # move service also calls cleanup callbacks
      next unless described_class == WorkItems::DataSync::MoveService

      allow_next_instance_of(callback_class, **cleanup_service_params) do |callback_instance|
        expect(callback_instance).to receive(:post_move_cleanup)
      end
    end

    service.execute
  end

  it 'returns a new work item with the same attributes' do
    new_work_item = service.execute[:work_item]

    expect(new_work_item).to be_persisted
    expect(new_work_item).to have_attributes(original_work_item_attrs)
  end

  it 'handles original work item state' do
    service.execute

    expect(original_work_item.reload.state_id).to eq(expected_original_work_item_state)
  end
end

RSpec.shared_examples 'cloneable and moveable widget data' do
  using RSpec::Parameterized::TableSyntax

  def set_assignees
    original_work_item.assignee_ids = assignees.map(&:id)
  end

  def work_item_assignees(work_item)
    work_item.reload.assignees
  end

  where(:widget_name, :eval_value, :before_lambda, :expected_data, :operations) do
    :assignees | :work_item_assignees | -> { set_assignees } | ref(:assignees) | [ref(:move), ref(:clone)]
  end

  with_them do
    context "with widget" do
      let(:move) { WorkItems::DataSync::MoveService }
      let(:clone) { WorkItems::DataSync::CloneService }

      before do
        instance_exec(&before_lambda)
      end

      it 'clones and moves widget data' do
        new_work_item = service.execute[:work_item]
        widget_value = send(eval_value, new_work_item)

        if operations.include?(described_class)
          expect(widget_value).not_to be_nil
          expect(widget_value).not_to be_empty
          expect(widget_value).to match_array(expected_data)
        else
          expect(widget_value).to be_empty
        end

        expect(original_work_item.reload.public_send(widget_name)).to be_empty if described_class == move
      end
    end
  end
end
