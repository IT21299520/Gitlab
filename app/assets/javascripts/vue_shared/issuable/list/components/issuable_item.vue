<script>
import {
  GlBadge,
  GlLink,
  GlIcon,
  GlLabel,
  GlFormCheckbox,
  GlSprintf,
  GlTooltipDirective,
} from '@gitlab/ui';
import { escapeRegExp } from 'lodash';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { STATUS_OPEN, STATUS_CLOSED } from '~/issues/constants';
import { isScopedLabel } from '~/lib/utils/common_utils';
import { isExternal, setUrlFragment, visitUrl } from '~/lib/utils/url_utility';
import { __, n__, sprintf } from '~/locale';
import IssuableAssignees from '~/issuable/components/issue_assignees.vue';

import timeagoMixin from '~/vue_shared/mixins/timeago';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import WorkItemTypeIcon from '~/work_items/components/work_item_type_icon.vue';
import WorkItemPrefetch from '~/work_items/components/work_item_prefetch.vue';
import { STATE_OPEN, STATE_CLOSED, LINKED_CATEGORIES_MAP } from '~/work_items/constants';
import { isAssigneesWidget, isLabelsWidget, findLinkedItemsWidget } from '~/work_items/utils';

export default {
  components: {
    GlBadge,
    GlLink,
    GlIcon,
    GlLabel,
    GlFormCheckbox,
    GlSprintf,
    IssuableAssignees,
    WorkItemTypeIcon,
    WorkItemPrefetch,
    WorkItemRelationshipIcons: () =>
      import('~/work_items/components/shared/work_item_relationship_icons.vue'),
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [timeagoMixin, glFeatureFlagMixin()],
  inject: {
    isGroup: {
      default: false,
    },
  },
  props: {
    hasScopedLabelsFeature: {
      type: Boolean,
      required: false,
      default: false,
    },
    issuableSymbol: {
      type: String,
      required: true,
    },
    fullPath: {
      type: String,
      required: false,
      default: null,
    },
    issuable: {
      type: Object,
      required: true,
    },
    labelFilterParam: {
      type: String,
      required: false,
      default: 'label_name',
    },
    showCheckbox: {
      type: Boolean,
      required: true,
    },
    checked: {
      type: Boolean,
      required: false,
      default: false,
    },
    showWorkItemTypeIcon: {
      type: Boolean,
      required: false,
      default: false,
    },
    isActive: {
      type: Boolean,
      required: false,
      default: false,
    },
    preventRedirect: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    issuableId() {
      return getIdFromGraphQLId(this.issuable.id) || this.issuable.id;
    },
    issuableIid() {
      return this.issuable.iid;
    },
    workItemFullPath() {
      return (
        this.issuable.namespace?.fullPath || this.issuable.reference?.split(this.issuableSymbol)[0]
      );
    },
    author() {
      return this.issuable.author || {};
    },
    externalAuthor() {
      return this.issuable.externalAuthor;
    },
    issuableLinkHref() {
      return this.issuable.webPath || this.issuable.gitlabWebUrl || this.issuable.webUrl;
    },
    authorId() {
      return getIdFromGraphQLId(this.author.id);
    },
    isIssuableUrlExternal() {
      return isExternal(this.issuableLinkHref ?? '');
    },
    reference() {
      return this.issuable.reference || `${this.issuableSymbol}${this.issuable.iid}`;
    },
    type() {
      return this.issuable.type || this.issuable.workItemType?.name.toUpperCase();
    },
    labels() {
      return (
        this.issuable.labels?.nodes ||
        this.issuable.labels ||
        this.issuable.widgets?.find(isLabelsWidget)?.labels.nodes ||
        []
      );
    },
    labelIdsString() {
      return JSON.stringify(this.labels.map((label) => getIdFromGraphQLId(label.id)));
    },
    assignees() {
      return (
        this.issuable.assignees?.nodes ||
        this.issuable.assignees ||
        this.issuable.widgets?.find(isAssigneesWidget)?.assignees.nodes ||
        []
      );
    },
    filteredLinkedItems() {
      const linkedItems = findLinkedItemsWidget(this.issuable)?.linkedItems?.nodes || [];
      return linkedItems.filter((item) => {
        return item.linkType !== LINKED_CATEGORIES_MAP.RELATES_TO;
      });
    },
    createdAt() {
      return this.timeFormatted(this.issuable.createdAt);
    },
    isOpen() {
      return [STATUS_OPEN, STATE_OPEN].includes(this.issuable.state);
    },
    isClosed() {
      return [STATUS_CLOSED, STATE_CLOSED].includes(this.issuable.state);
    },
    timestamp() {
      return this.isClosed && this.issuable.closedAt
        ? this.issuable.closedAt
        : this.issuable.updatedAt;
    },
    formattedTimestamp() {
      if (this.isClosed && this.issuable.closedAt) {
        return sprintf(__('closed %{timeago}'), {
          timeago: this.timeFormatted(this.issuable.closedAt),
        });
      }
      if (this.issuable.updatedAt !== this.issuable.createdAt) {
        return sprintf(__('updated %{timeAgo}'), {
          timeAgo: this.timeFormatted(this.issuable.updatedAt),
        });
      }
      return undefined;
    },
    issuableTitleProps() {
      if (this.isIssuableUrlExternal) {
        return {
          target: '_blank',
        };
      }
      return {};
    },
    taskStatus() {
      const { completedCount, count } = this.issuable.taskCompletionStatus || {};
      if (!count) {
        return undefined;
      }

      return sprintf(
        n__(
          '%{completedCount} of %{count} checklist item completed',
          '%{completedCount} of %{count} checklist items completed',
          count,
        ),
        { completedCount, count },
      );
    },
    notesCount() {
      return this.issuable.userDiscussionsCount ?? this.issuable.userNotesCount;
    },
    showDiscussions() {
      return typeof this.notesCount === 'number';
    },
    showIssuableMeta() {
      return Boolean(
        this.hasSlotContents('status') ||
          this.hasSlotContents('statistics') ||
          this.showDiscussions ||
          this.issuable.assignees,
      );
    },
    issuableNotesLink() {
      return setUrlFragment(this.issuableLinkHref, 'notes');
    },
    statusBadgeVariant() {
      if (this.isMergeRequest && this.isClosed) {
        return 'danger';
      }

      return 'info';
    },
    isMergeRequest() {
      // eslint-disable-next-line no-underscore-dangle
      return this.issuable.__typename === 'MergeRequest';
    },
    issueAsWorkItem() {
      return (
        !this.isGroup &&
        this.glFeatures.workItemsViewPreference &&
        gon.current_user_use_work_items_view
      );
    },
    hiddenIssuableTitle() {
      if (this.isMergeRequest) {
        return __('This merge request is hidden because its author has been banned.');
      }

      return __('This issue is hidden because its author has been banned.');
    },
  },
  methods: {
    hasSlotContents(slotName) {
      // eslint-disable-next-line @gitlab/vue-prefer-dollar-scopedslots
      return Boolean(this.$slots[slotName]);
    },
    scopedLabel(label) {
      const allowsScopedLabels =
        this.hasScopedLabelsFeature ||
        this.issuable.widgets?.find(isLabelsWidget)?.allowsScopedLabels;
      return allowsScopedLabels && isScopedLabel(label);
    },
    labelTitle(label) {
      return label.title || label.name;
    },
    labelTarget(label) {
      const value = encodeURIComponent(this.labelTitle(label));
      return `?${this.labelFilterParam}[]=${value}`;
    },
    /**
     * This is needed as an independent method since
     * when user changes current page, `$refs.authorLink`
     * will be null until next page results are loaded & rendered.
     */
    getAuthorPopoverTarget() {
      if (this.$refs.authorLink) {
        return this.$refs.authorLink.$el;
      }
      return '';
    },
    handleIssuableItemClick(e) {
      if (e.metaKey || e.ctrlKey || this.showCheckbox || e.button === 1) {
        return;
      }
      e.preventDefault();
      if (!this.preventRedirect) {
        this.navigateToIssuable();
        return;
      }
      this.$emit('select-issuable', {
        id: this.issuable.id,
        iid: this.issuableIid,
        webUrl: this.issuable.webUrl,
        fullPath: this.workItemFullPath,
        workItemType: this.type.toLowerCase(),
      });
    },
    navigateToIssuable() {
      if (!this.fullPath) {
        visitUrl(this.issuableLinkHref);
      }
      const escapedFullPath = escapeRegExp(this.fullPath);
      // eslint-disable-next-line no-useless-escape
      const regex = new RegExp(`groups\/${escapedFullPath}\/-\/(work_items|epics)\/\\d+`);
      const isWorkItemPath = regex.test(this.issuableLinkHref);

      if (isWorkItemPath || this.issueAsWorkItem) {
        this.$router.push({
          name: 'workItem',
          params: {
            iid: this.issuableIid,
          },
        });
      } else {
        visitUrl(this.issuableLinkHref);
      }
    },
    handleRowClick(e) {
      if (this.preventRedirect) {
        this.handleIssuableItemClick(e);
      }
    },
  },
};
</script>

<template>
  <li
    :id="`issuable_${issuableId}`"
    class="issue !gl-flex !gl-px-5"
    :class="{
      closed: issuable.closedAt,
      'gl-bg-blue-50': isActive,
      'gl-cursor-pointer': preventRedirect && !showCheckbox,
      'hover:gl-bg-subtle': preventRedirect && !isActive && !showCheckbox,
    }"
    :data-labels="labelIdsString"
    :data-qa-issue-id="issuableId"
    data-testid="issuable-item-wrapper"
    @click="handleRowClick"
  >
    <gl-form-checkbox
      v-if="showCheckbox"
      :checked="checked"
      :data-id="issuableId"
      :data-iid="issuableIid"
      :data-type="type"
      @input="$emit('checked-input', $event)"
    >
      <span class="gl-sr-only">{{ issuable.title }}</span>
    </gl-form-checkbox>
    <div class="issuable-main-info">
      <div data-testid="issuable-title" class="issue-title title gl-font-size-0">
        <work-item-type-icon
          v-if="showWorkItemTypeIcon"
          class="gl-mr-2"
          :work-item-type="type"
          show-tooltip-on-hover
        />
        <gl-icon
          v-if="issuable.confidential"
          v-gl-tooltip
          name="eye-slash"
          :title="__('Confidential')"
          :aria-label="__('Confidential')"
          class="gl-mr-2"
        />
        <gl-icon
          v-if="issuable.hidden"
          v-gl-tooltip
          name="spam"
          :title="hiddenIssuableTitle"
          :aria-label="__('Hidden')"
        />
        <work-item-prefetch
          v-if="preventRedirect"
          :work-item-iid="issuableIid"
          :work-item-full-path="workItemFullPath"
          data-testid="issuable-prefetch-trigger"
        >
          <template #default="{ prefetchWorkItem, clearPrefetching }">
            <gl-link
              class="issue-title-text gl-text-base"
              dir="auto"
              :href="issuableLinkHref"
              data-testid="issuable-title-link"
              v-bind="issuableTitleProps"
              @click.stop="handleIssuableItemClick"
              @mouseover.native="prefetchWorkItem(issuableIid)"
              @mouseout.native="clearPrefetching"
            >
              {{ issuable.title }}
              <gl-icon v-if="isIssuableUrlExternal" name="external-link" class="gl-ml-2" />
            </gl-link>
          </template>
        </work-item-prefetch>
        <gl-link
          v-else
          class="issue-title-text gl-text-base"
          dir="auto"
          :href="issuableLinkHref"
          data-testid="issuable-title-link"
          v-bind="issuableTitleProps"
          @click.stop="handleIssuableItemClick"
        >
          {{ issuable.title }}
          <gl-icon v-if="isIssuableUrlExternal" name="external-link" class="gl-ml-2" />
        </gl-link>
        <slot v-if="hasSlotContents('title-icons')" name="title-icons"></slot>
        <span
          v-if="taskStatus"
          class="task-status gl-ml-2 gl-hidden gl-text-sm sm:!gl-inline-block"
          data-testid="task-status"
        >
          {{ taskStatus }}
        </span>
      </div>
      <div class="issuable-info">
        <slot v-if="hasSlotContents('reference')" name="reference"></slot>
        <span v-else data-testid="issuable-reference" class="issuable-reference">
          {{ reference }}
        </span>
        <span class="gl-hidden sm:gl-inline">
          <span aria-hidden="true">&middot;</span>
          <span class="issuable-authored gl-mr-3">
            <gl-sprintf v-if="author.name" :message="__('created %{timeAgo} by %{author}')">
              <template #timeAgo>
                <span
                  v-gl-tooltip.bottom
                  :title="tooltipTitle(issuable.createdAt)"
                  data-testid="issuable-created-at"
                >
                  {{ createdAt }}
                </span>
              </template>
              <template #author>
                <span v-if="externalAuthor" data-testid="external-author"
                  >{{ externalAuthor }} {{ __('via') }}</span
                >
                <slot v-if="hasSlotContents('author')" name="author"></slot>
                <gl-link
                  v-else
                  :data-user-id="authorId"
                  :data-username="author.username"
                  :data-name="author.name"
                  :data-avatar-url="author.avatarUrl"
                  :href="author.webPath"
                  data-testid="issuable-author"
                  class="author-link js-user-link gl-text-sm !gl-text-gray-500"
                  @click.stop
                >
                  <span class="author">{{ author.name }}</span>
                </gl-link>
              </template>
            </gl-sprintf>
            <gl-sprintf v-else :message="__('created %{timeAgo}')">
              <template #timeAgo>
                <span
                  v-gl-tooltip.bottom
                  :title="tooltipTitle(issuable.createdAt)"
                  data-testid="issuable-created-at"
                >
                  {{ createdAt }}
                </span>
              </template>
            </gl-sprintf>
          </span>
          <slot name="timeframe"></slot>
          <slot name="target-branch"></slot>
        </span>
        <p
          v-if="labels.length"
          role="group"
          :aria-label="__('Labels')"
          class="gl-mb-0 gl-mt-1 gl-flex gl-flex-wrap gl-gap-2"
        >
          <gl-label
            v-for="(label, index) in labels"
            :key="index"
            :background-color="label.color"
            :title="labelTitle(label)"
            :description="label.description"
            :scoped="scopedLabel(label)"
            :target="labelTarget(label)"
            @click.stop
          />
        </p>
      </div>
    </div>
    <div class="issuable-meta">
      <ul v-if="showIssuableMeta" class="controls gl-gap-3">
        <!-- eslint-disable-next-line @gitlab/vue-prefer-dollar-scopedslots -->
        <li v-if="$slots.status" data-testid="issuable-status" class="!gl-mr-0">
          <gl-badge v-if="!isOpen" :variant="statusBadgeVariant">
            <slot name="status"></slot>
          </gl-badge>
          <slot v-else name="status"></slot>
        </li>
        <slot name="approval-status"></slot>
        <slot name="pipeline-status"></slot>
        <li v-if="assignees.length" class="!gl-mr-0">
          <issuable-assignees
            :assignees="assignees"
            :icon-size="16"
            :max-visible="4"
            class="gl-flex gl-items-center"
          />
        </li>
        <slot name="reviewers"></slot>
        <li
          v-if="showDiscussions && notesCount"
          class="!gl-mr-0 gl-hidden sm:gl-block"
          data-testid="issuable-comments"
        >
          <div
            v-gl-tooltip.top
            :title="__('Comments')"
            class="gl-flex gl-items-center !gl-text-inherit"
          >
            <gl-icon name="comments" class="gl-mr-2" />
            {{ notesCount }}
          </div>
        </li>
        <slot name="statistics"></slot>
        <work-item-relationship-icons
          v-if="isOpen && filteredLinkedItems.length > 0"
          :work-item-type="type"
          :linked-work-items="filteredLinkedItems"
          :work-item-full-path="workItemFullPath"
          :work-item-iid="issuableIid"
          :work-item-web-url="issuableLinkHref"
        />
      </ul>
      <div
        v-gl-tooltip.bottom
        class="gl-hidden gl-text-gray-500 sm:gl-inline-block"
        :title="tooltipTitle(timestamp)"
        data-testid="issuable-timestamp"
      >
        {{ formattedTimestamp }}
      </div>
    </div>
  </li>
</template>
