---
stage: Verify
group: Runner
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# Datadog

DETAILS:
**Tier:** Free, Premium, Ultimate
**Offering:** GitLab.com, Self-managed, GitLab Dedicated

The Datadog integration enables you to send CI/CD pipeline and job information to
[Datadog](https://www.datadoghq.com/). The [Datadog CI Pipeline Visibility](https://www.datadoghq.com/product/ci-cd-monitoring/)
product helps you monitor for job failures and performance issues, then troubleshoot them.
It's based on [Webhooks](../user/project/integrations/webhooks.md),
and only requires configuration on GitLab.

## Configure the integration

Users with the **Administrator** role can configure the integration for the entire instance
or for a specific project or group:

1. If you do not have a Datadog API key:
   1. Sign in to Datadog.
   1. Go to the **Integrations** section.
   1. Generate an API key in the [APIs tab](https://app.datadoghq.com/account/settings#api).
      Copy this value, as you need it in a later step.
1. *For integrations for a specific project or group:* In GitLab, go to your project or group.
1. *For integrations for the entire instance:*
   1. Sign in to GitLab as a user with administrator access.
   1. On the left sidebar, at the bottom, select **Admin**.
1. Select **Settings > Integrations**.
1. Scroll to **Add an integration**, and select **Datadog**.
1. Select **Active** to enable the integration.
1. Specify the [**Datadog site**](https://docs.datadoghq.com/getting_started/site/) to send data to.
1. Provide your Datadog **API key**.
1. Optional. Select **Enable logs collection** to enable logs collection for the output of jobs. ([Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/346339) in GitLab 15.3.)
1. Optional. To override the API URL used to send data directly, provide an **API URL**.
   Used only in advanced scenarios.
1. Optional. If you use more than one GitLab instance, provide a unique **Service** name
   to differentiate between your GitLab instances.
<!-- vale gitlab_base.Spelling = NO -->
1. Optional. If you use groups of GitLab instances (such as staging and production
   environments), provide an **Env** name. This value is attached to each span
   the integration generates.
<!-- vale gitlab_base.Spelling = YES -->
1. Optional. To define any custom tags for all spans at which the integration is being configured,
   enter one tag per line in **Tags**. Each line must be in the format `key:value`.
1. Optional. Select **Test settings**.
1. Select **Save changes**.

When the integration sends data, you can view it in the [CI Visibility](https://app.datadoghq.com/ci)
section of your Datadog account.

## Related topics

- [Datadog CI Visibility documentation](https://docs.datadoghq.com/continuous_integration/)
