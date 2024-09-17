# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/AvoidTestProf -- this is not a migration spec
RSpec.describe 'keep-around tasks', :silence_stdout, feature_category: :source_code_management do
  include ProjectForksHelper

  before do
    Rake.application.rake_require 'tasks/gitlab/keep_around'
  end

  describe 'orphaned' do
    subject { run_rake_task('gitlab:keep_around:orphaned') }

    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:keep_around_shas) do
      # Keep-around references only on branch tips is not necessarily accurate,
      # but this constant gives convenient access to commit IDs that actually
      # exist.
      ::TestEnv::BRANCH_SHA.slice(
        'master',
        'changes-with-whitespace',
        'changes-with-only-whitespace'
      ).values.uniq
    end

    let(:logger) { instance_double(::Logger) }
    let(:file) { Tempfile.new("orphan_report.csv") }
    let(:project_id_env) { project.id }
    let(:project_path_env) { nil }
    let(:filename_env) { file.path }

    before do
      allow(main_object).to receive(:logger).and_return(logger).at_least(:once)

      allow(logger).to receive(:info).at_least(:once)
      allow(logger).to receive(:debug).at_least(:once)
      allow(logger).to receive(:warn).at_least(:once)

      stub_env('PROJECT_ID', project_id_env)
      stub_env('PROJECT_PATH', project_path_env)
      stub_env('FILENAME', filename_env)

      ::Gitlab::Git::KeepAround.new(project.repository).execute(
        keep_around_shas,
        source: "keep_around_rake_spec"
      )
    end

    after do
      file.unlink
    end

    shared_examples 'orphans found' do |keep_around_count:, orphan_count:|
      it 'prints a summary' do
        expect(logger).to receive(:info).with("Summary:")
        expect(logger).to receive(:info).with("\tKeep-around references: #{keep_around_count}")
        expect(logger).to receive(:info).with("\tPotentially orphaned: #{orphan_count}")

        run_rake_task('gitlab:keep_around:orphaned')
      end
    end

    context "without project" do
      let(:project_id_env) { nil }

      it 'exits with instructions' do
        expect(logger).to receive(:info).with(
          "Specify the project with PROJECT_ID={number} or PROJECT_PATH={namespace/project-name}"
        )

        expect do
          run_rake_task('gitlab:keep_around:orphaned')
        end.to raise_error(SystemExit)
      end
    end

    context "without filename" do
      let(:filename_env) { nil }

      it 'exits with instructions' do
        expect(logger).to receive(:info).with("Specify the CSV output file with FILENAME={path}")

        expect do
          run_rake_task('gitlab:keep_around:orphaned')
        end.to raise_error(SystemExit)
      end
    end

    context "with project path" do
      let(:project_id_env) { nil }
      let(:project_path_env) { project.full_path }

      it_behaves_like 'orphans found',
        keep_around_count: 3,
        orphan_count: 3
    end

    context "with only orphaned keep-arounds" do
      it_behaves_like 'orphans found',
        keep_around_count: 3,
        orphan_count: 3
    end

    context "for pipeline keep-arounds" do
      let_it_be(:pipeline) { create(:ci_empty_pipeline, :created, project: project) }

      it_behaves_like 'orphans found',
        keep_around_count: 3,
        orphan_count: 2
    end

    context "for merge request keep-arounds" do
      let_it_be(:fork) { fork_project(project, nil, repository: true) }
      let_it_be(:merge_request) { create(:merge_request, target_project: project, source_project: fork) }

      it_behaves_like 'orphans found',
        keep_around_count: 3,
        orphan_count: 2
    end

    context "for diff note keep-arounds" do
      let_it_be(:diff_note) do
        create(:diff_note_on_merge_request, project: project, commit_id: ::TestEnv::BRANCH_SHA['master'])
      end

      it_behaves_like 'orphans found',
        keep_around_count: 3,
        orphan_count: 2
    end

    context "for note keep-arounds" do
      let_it_be(:note) { create(:note_on_commit, project: project, commit_id: ::TestEnv::BRANCH_SHA['master']) }

      it_behaves_like 'orphans found',
        keep_around_count: 3,
        orphan_count: 2
    end

    context "for sent notification keep-arounds" do
      let_it_be(:sent_notification) do
        create(:sent_notification, project: project, commit_id: ::TestEnv::BRANCH_SHA['master'])
      end

      it_behaves_like 'orphans found',
        keep_around_count: 3,
        orphan_count: 2
    end

    context "for todo keep-arounds" do
      let_it_be(:todo) { create(:todo, project: project, commit_id: ::TestEnv::BRANCH_SHA['master']) }

      it_behaves_like 'orphans found',
        keep_around_count: 3,
        orphan_count: 2
    end
  end
end
# rubocop:enable RSpec/AvoidTestProf
