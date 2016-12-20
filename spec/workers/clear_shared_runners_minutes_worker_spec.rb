require 'spec_helper'

describe ClearSharedRunnersMinutesWorker do
  let(:worker) { described_class.new }

  describe '#perform' do
    before do
      expect_any_instance_of(described_class).
        to receive(:try_obtain_lease).and_return(true)
    end

    subject { worker.perform }

    context 'when project metrics are defined' do
      let!(:project_metrics) { create(:project_metrics, shared_runners_minutes: 100) }

      it 'clears counters' do
        subject

        expect(project_metrics.reload.shared_runners_minutes).to be_zero
      end

      it 'resets timer' do
        subject

        expect(project_metrics.reload.shared_runners_minutes_last_reset).to be_like_time(Time.now)
      end
    end

    context 'when project metrics are defined' do
      let!(:namespace_metrics) { create(:namespace_metrics, shared_runners_minutes: 100) }

      it 'clears counters' do
        subject

        expect(namespace_metrics.reload.shared_runners_minutes).to be_zero
      end

      it 'resets timer' do
        subject

        expect(namespace_metrics.reload.shared_runners_minutes_last_reset).to be_like_time(Time.now)
      end
    end
  end
end
