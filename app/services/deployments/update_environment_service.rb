# frozen_string_literal: true

module Deployments
  class UpdateEnvironmentService
    attr_reader :deployment
    attr_reader :deployable

    delegate :environment, to: :deployment
    delegate :variables, to: :deployable
    delegate :options, to: :deployable, allow_nil: true

    EnvironmentUpdateFailure = Class.new(StandardError)

    def initialize(deployment)
      @deployment = deployment
      @deployable = deployment.deployable
    end

    def execute
      deployment.create_ref
      deployment.invalidate_cache

      update_environment(deployment)

      deployment
    end

    def update_environment(deployment)
      ApplicationRecord.transaction do
        # Renew attributes at update
        renew_external_url
        renew_auto_stop_in
        renew_deployment_tier
        renew_cluster_agent
        environment.fire_state_event(action)

        if environment.save
          deployment.update_merge_request_metrics! unless environment.stopped?
        else
          # If there is a validation error on environment update, such as
          # the external URL is malformed, the error message is recorded for debugging purpose.
          # We should surface the error message to users for letting them to take an action.
          # See https://gitlab.com/gitlab-org/gitlab/-/issues/21182.
          Gitlab::ErrorTracking.track_exception(
            EnvironmentUpdateFailure.new,
            project_id: deployment.project_id,
            environment_id: environment.id,
            reason: environment.errors.full_messages.to_sentence)
        end
      end
    end

    private

    def environment_options
      options&.dig(:environment) || {}
    end

    def expanded_environment_url
      return unless environment_url

      ExpandVariables.expand(environment_url, -> { variables.sort_and_expand_all })
    end

    def expanded_auto_stop_in
      return unless auto_stop_in

      ExpandVariables.expand(auto_stop_in, -> { variables.sort_and_expand_all })
    end

    def expanded_cluster_agent_path
      return unless cluster_agent_path

      ExpandVariables.expand(cluster_agent_path, -> { variables.sort_and_expand_all })
    end

    def environment_url
      environment_options[:url]
    end

    def action
      environment_options[:action] || 'start'
    end

    def auto_stop_in
      deployable&.environment_auto_stop_in
    end

    def cluster_agent_path
      environment_options.dig(:kubernetes, :agent)
    end

    def renew_external_url
      if (url = expanded_environment_url)
        environment.external_url = url
      end
    end

    def renew_auto_stop_in
      return unless deployable

      if (value = expanded_auto_stop_in)
        environment.auto_stop_in = value
      end
    end

    def renew_deployment_tier
      return unless deployable

      if (tier = deployable.environment_tier_from_options)
        environment.tier = tier
      end
    end

    def renew_cluster_agent
      return unless cluster_agent_path && deployable.user

      requested_project_path, requested_agent_name = expanded_cluster_agent_path.split(':')

      matching_authorization = user_access_authorizations_for_project.find do |authorization|
        requested_project_path == authorization.config_project.full_path &&
          requested_agent_name == authorization.agent.name
      end

      return unless matching_authorization

      environment.cluster_agent = matching_authorization.agent
    end

    def user_access_authorizations_for_project
      Clusters::Agents::Authorizations::UserAccess::Finder.new(deployable.user, project: deployable.project).execute
    end
  end
end

Deployments::UpdateEnvironmentService.prepend_mod_with('Deployments::UpdateEnvironmentService')
