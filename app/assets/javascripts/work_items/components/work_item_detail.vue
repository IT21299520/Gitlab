<script>
import { isEmpty } from 'lodash';
import { GlAlert, GlButton, GlTooltipDirective, GlEmptyState } from '@gitlab/ui';
import noAccessSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import { getParameterByName, updateHistory, setUrlParams } from '~/lib/utils/url_utility';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP, TYPENAME_WORK_ITEM } from '~/graphql_shared/constants';
import { isLoggedIn } from '~/lib/utils/common_utils';
import { WORKSPACE_PROJECT } from '~/issues/constants';
import {
  i18n,
  DETAIL_VIEW_QUERY_PARAM_NAME,
  WIDGET_TYPE_ASSIGNEES,
  WIDGET_TYPE_NOTIFICATIONS,
  WIDGET_TYPE_CURRENT_USER_TODOS,
  WIDGET_TYPE_DESCRIPTION,
  WIDGET_TYPE_AWARD_EMOJI,
  WIDGET_TYPE_HIERARCHY,
  WORK_ITEM_TYPE_VALUE_OBJECTIVE,
  WIDGET_TYPE_NOTES,
  WIDGET_TYPE_LINKED_ITEMS,
  WIDGET_TYPE_DESIGNS,
  LINKED_ITEMS_ANCHOR,
  WORK_ITEM_REFERENCE_CHAR,
  WORK_ITEM_TYPE_VALUE_TASK,
  WORK_ITEM_TYPE_VALUE_EPIC,
  WIDGET_TYPE_WEIGHT,
} from '../constants';

import workItemUpdatedSubscription from '../graphql/work_item_updated.subscription.graphql';
import updateWorkItemMutation from '../graphql/update_work_item.mutation.graphql';
import workItemByIdQuery from '../graphql/work_item_by_id.query.graphql';
import workItemByIidQuery from '../graphql/work_item_by_iid.query.graphql';
import getAllowedWorkItemChildTypes from '../graphql/work_item_allowed_children.query.graphql';
import workspacePermissionsQuery from '../graphql/workspace_permissions.query.graphql';
import { findHierarchyWidgetDefinition } from '../utils';
import { updateWorkItemCurrentTodosWidget } from '../graphql/cache_utils';

import getWorkItemDesignListQuery from './design_management/graphql/design_collection.query.graphql';
import uploadDesignMutation from './design_management/graphql/upload_design.mutation.graphql';
import { designUploadOptimisticResponse } from './design_management/utils';
import { updateStoreAfterUploadDesign } from './design_management/cache_updates';
import {
  MAXIMUM_FILE_UPLOAD_LIMIT,
  MAXIMUM_FILE_UPLOAD_LIMIT_REACHED,
  designUploadSkippedWarning,
  UPLOAD_DESIGN_ERROR_MESSAGE,
} from './design_management/constants';

import WorkItemTree from './work_item_links/work_item_tree.vue';
import WorkItemActions from './work_item_actions.vue';
import TodosToggle from './shared/todos_toggle.vue';
import WorkItemNotificationsWidget from './work_item_notifications_widget.vue';
import WorkItemAttributesWrapper from './work_item_attributes_wrapper.vue';
import WorkItemCreatedUpdated from './work_item_created_updated.vue';
import WorkItemDescription from './work_item_description.vue';
import WorkItemNotes from './work_item_notes.vue';
import WorkItemDetailModal from './work_item_detail_modal.vue';
import WorkItemAwardEmoji from './work_item_award_emoji.vue';
import WorkItemRelationships from './work_item_relationships/work_item_relationships.vue';
import WorkItemStickyHeader from './work_item_sticky_header.vue';
import WorkItemAncestors from './work_item_ancestors/work_item_ancestors.vue';
import WorkItemTitle from './work_item_title.vue';
import WorkItemLoading from './work_item_loading.vue';
import WorkItemAbuseModal from './work_item_abuse_modal.vue';
import DesignWidget from './design_management/design_management_widget.vue';
import DesignUploadButton from './design_management/upload_button.vue';

const defaultWorkspacePermissions = {
  createDesign: false,
};

export default {
  name: 'WorkItemDetail',
  i18n,
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  isLoggedIn: isLoggedIn(),
  components: {
    DesignWidget,
    DesignUploadButton,
    GlAlert,
    GlButton,
    GlEmptyState,
    WorkItemActions,
    TodosToggle,
    WorkItemNotificationsWidget,
    WorkItemCreatedUpdated,
    WorkItemDescription,
    WorkItemAwardEmoji,
    WorkItemAttributesWrapper,
    WorkItemTree,
    WorkItemNotes,
    WorkItemDetailModal,
    WorkItemRelationships,
    WorkItemStickyHeader,
    WorkItemAncestors,
    WorkItemTitle,
    WorkItemLoading,
    WorkItemAbuseModal,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['fullPath', 'reportAbusePath', 'groupPath', 'hasSubepicsFeature'],
  props: {
    isModal: {
      type: Boolean,
      required: false,
      default: false,
    },
    workItemId: {
      type: String,
      required: false,
      default: null,
    },
    workItemIid: {
      type: String,
      required: false,
      default: null,
    },
    modalWorkItemFullPath: {
      type: String,
      required: false,
      default: '',
    },
    modalIsGroup: {
      type: Boolean,
      required: false,
      default: null,
    },
    isDrawer: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    let modalWorkItemId = getParameterByName(DETAIL_VIEW_QUERY_PARAM_NAME);

    if (modalWorkItemId) {
      modalWorkItemId = convertToGraphQLId(TYPENAME_WORK_ITEM, modalWorkItemId);
    }

    return {
      error: undefined,
      updateError: undefined,
      workItem: {},
      updateInProgress: false,
      modalWorkItemId,
      modalWorkItemIid: getParameterByName('work_item_iid'),
      modalWorkItemNamespaceFullPath: '',
      isReportModalOpen: false,
      reportedUrl: '',
      reportedUserId: 0,
      isStickyHeaderShowing: false,
      editMode: false,
      draftData: {},
      hasChildren: false,
      filesToBeSaved: [],
      allowedChildTypes: [],
      designUploadError: null,
      workspacePermissions: defaultWorkspacePermissions,
    };
  },
  apollo: {
    workItem: {
      query() {
        if (this.workItemId) {
          return workItemByIdQuery;
        }
        return workItemByIidQuery;
      },
      variables() {
        if (this.workItemId) {
          return {
            id: this.workItemId,
          };
        }
        return {
          fullPath: this.workItemFullPath,
          iid: this.workItemIid,
        };
      },
      skip() {
        return !this.workItemIid && !this.workItemId;
      },
      update(data) {
        if (this.workItemId) {
          return data.workItem ?? {};
        }
        return data.workspace.workItem ?? {};
      },
      error() {
        this.setEmptyState();
      },
      result(res) {
        // need to handle this when the res is loading: true, netWorkStatus: 1, partial: true
        if (!res.data) {
          return;
        }
        this.$emit('work-item-updated', this.workItem);
        if (isEmpty(this.workItem)) {
          this.setEmptyState();
        }
        if (!(this.isModal || this.isDrawer) && this.workItem.namespace) {
          const path = this.workItem.namespace.fullPath
            ? ` · ${this.workItem.namespace.fullPath}`
            : '';

          document.title = `${this.workItem.title} (${WORK_ITEM_REFERENCE_CHAR}${this.workItem.iid}) · ${this.workItem?.workItemType?.name}${path}`;
        }
      },
      subscribeToMore: {
        document: workItemUpdatedSubscription,
        variables() {
          return {
            id: this.workItem.id,
          };
        },
        skip() {
          return !this.workItem?.id;
        },
      },
    },
    allowedChildTypes: {
      query: getAllowedWorkItemChildTypes,
      variables() {
        return {
          id: this.workItem.id,
        };
      },
      skip() {
        return !this.workItem?.id;
      },
      update(data) {
        return findHierarchyWidgetDefinition(data.workItem)?.allowedChildTypes?.nodes || [];
      },
    },
    workspacePermissions: {
      query: workspacePermissionsQuery,
      variables() {
        return {
          fullPath: this.workItemFullPath,
        };
      },
      skip() {
        return this.isGroupWorkItem || this.workItemLoading;
      },
      update(data) {
        return data.workspace?.userPermissions ?? defaultWorkspacePermissions;
      },
    },
  },
  computed: {
    workItemFullPath() {
      return this.modalWorkItemFullPath || this.fullPath;
    },
    workItemLoading() {
      return isEmpty(this.workItem) && this.$apollo.queries.workItem.loading;
    },
    workItemType() {
      return this.workItem.workItemType?.name;
    },
    workItemTypeId() {
      return this.workItem.workItemType?.id;
    },
    workItemAuthorId() {
      return getIdFromGraphQLId(this.workItem.author?.id);
    },
    canUpdate() {
      return this.workItem.userPermissions?.updateWorkItem;
    },
    canUpdateChildren() {
      return this.workItem.userPermissions?.adminParentLink;
    },
    canDelete() {
      return this.workItem.userPermissions?.deleteWorkItem;
    },
    canSetWorkItemMetadata() {
      return this.workItem.userPermissions?.setWorkItemMetadata;
    },
    canAdminWorkItemLink() {
      return this.workItem.userPermissions?.adminWorkItemLink;
    },
    canAssignUnassignUser() {
      return this.workItemAssignees && this.canSetWorkItemMetadata;
    },
    isDiscussionLocked() {
      return this.workItemNotes?.discussionLocked;
    },
    workItemsAlphaEnabled() {
      return this.glFeatures.workItemsAlpha;
    },
    newTodoAndNotificationsEnabled() {
      return this.glFeatures.notificationsTodosButtons;
    },
    parentWorkItem() {
      return this.isWidgetPresent(WIDGET_TYPE_HIERARCHY)?.parent;
    },
    hasParent() {
      const { workItemType, parentWorkItem, hasSubepicsFeature } = this;

      if (workItemType === WORK_ITEM_TYPE_VALUE_EPIC) {
        return hasSubepicsFeature && parentWorkItem;
      }

      return Boolean(parentWorkItem);
    },
    shouldShowAncestors() {
      // TODO: This is a temporary check till the issue work item migration is completed
      // Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/468114
      if (
        this.workItemType === WORK_ITEM_TYPE_VALUE_TASK &&
        !this.glFeatures.namespaceLevelWorkItems
      ) {
        return false;
      }

      // Checks whether current work item has parent
      // or it is in hierarchy but there is no permission to view the parent
      return this.hasParent || this.workItemHierarchy?.hasParent;
    },
    parentWorkItemConfidentiality() {
      return this.parentWorkItem?.confidential;
    },
    workItemIconName() {
      return this.workItem.workItemType?.iconName;
    },
    hasDescriptionWidget() {
      return this.isWidgetPresent(WIDGET_TYPE_DESCRIPTION);
    },
    hasDesignWidget() {
      return this.isWidgetPresent(WIDGET_TYPE_DESIGNS) && this.$router;
    },
    showUploadDesign() {
      return this.hasDesignWidget && this.workspacePermissions.createDesign;
    },
    workItemNotificationsSubscribed() {
      return Boolean(this.isWidgetPresent(WIDGET_TYPE_NOTIFICATIONS)?.subscribed);
    },
    workItemCurrentUserTodos() {
      return this.isWidgetPresent(WIDGET_TYPE_CURRENT_USER_TODOS);
    },
    showWorkItemCurrentUserTodos() {
      return Boolean(this.$options.isLoggedIn && this.workItemCurrentUserTodos);
    },
    currentUserTodos() {
      return this.workItemCurrentUserTodos?.currentUserTodos?.nodes;
    },
    workItemAssignees() {
      return this.isWidgetPresent(WIDGET_TYPE_ASSIGNEES);
    },
    workItemAwardEmoji() {
      return this.isWidgetPresent(WIDGET_TYPE_AWARD_EMOJI);
    },
    workItemHierarchy() {
      return this.isWidgetPresent(WIDGET_TYPE_HIERARCHY);
    },
    workItemNotes() {
      return this.isWidgetPresent(WIDGET_TYPE_NOTES);
    },
    workItemWeight() {
      return this.isWidgetPresent(WIDGET_TYPE_WEIGHT);
    },
    workItemBodyClass() {
      return {
        'gl-pt-5': !this.updateError && !this.isModal,
      };
    },
    showIntersectionObserver() {
      return !this.isModal && !this.editMode && !this.isDrawer;
    },
    workItemLinkedItems() {
      return this.isWidgetPresent(WIDGET_TYPE_LINKED_ITEMS);
    },
    showWorkItemTree() {
      return this.isWidgetPresent(WIDGET_TYPE_HIERARCHY) && this.allowedChildTypes?.length > 0;
    },
    titleClassHeader() {
      return {
        'sm:!gl-hidden gl-mt-3': this.shouldShowAncestors,
        'sm:!gl-block': !this.shouldShowAncestors,
        'gl-w-full': !this.shouldShowAncestors && !this.editMode,
        'editable-wi-title': this.editMode && !this.shouldShowAncestors,
      };
    },
    titleClassComponent() {
      return {
        'sm:!gl-block': !this.shouldShowAncestors,
        'gl-hidden sm:!gl-block gl-mt-3': this.shouldShowAncestors,
        'editable-wi-title': this.workItemsAlphaEnabled,
      };
    },
    shouldShowEditButton() {
      return !this.editMode && this.canUpdate;
    },
    modalCloseButtonClass() {
      return {
        'sm:gl-hidden': !this.error,
        'gl-flex': true,
      };
    },
    workItemPresent() {
      return !isEmpty(this.workItem);
    },
    isGroupWorkItem() {
      return Boolean(this.modalIsGroup ?? this.workItem.namespace?.id.includes(TYPENAME_GROUP));
    },
    isSaving() {
      return this.filesToBeSaved.length > 0;
    },
    designCollectionQueryBody() {
      return {
        query: getWorkItemDesignListQuery,
        variables: { id: this.workItem.id, atVersion: null },
      };
    },
    iid() {
      return this.workItemIid || this.workItem.iid;
    },
  },
  mounted() {
    if (this.modalWorkItemId) {
      this.openInModal({
        event: undefined,
        modalWorkItem: { id: this.modalWorkItemId },
      });
    }
  },
  methods: {
    enableEditMode() {
      this.editMode = true;
    },
    isWidgetPresent(type) {
      return this.workItem.widgets?.find((widget) => widget.type === type);
    },
    toggleConfidentiality(confidentialStatus) {
      this.updateInProgress = true;

      this.$apollo
        .mutate({
          mutation: updateWorkItemMutation,
          variables: {
            input: {
              id: this.workItem.id,
              confidential: confidentialStatus,
            },
          },
        })
        .then(
          ({
            data: {
              workItemUpdate: { errors, workItem },
            },
          }) => {
            if (errors?.length) {
              throw new Error(errors[0]);
            }

            this.$emit('workItemUpdated', {
              confidential: workItem?.confidential,
            });
          },
        )
        .catch((error) => {
          this.updateError = error.message;
        })
        .finally(() => {
          this.updateInProgress = false;
        });
    },
    setEmptyState() {
      this.error = this.$options.i18n.fetchError;
      document.title = s__('404|Not found');
    },
    updateUrl(modalWorkItem) {
      updateHistory({
        url: setUrlParams({
          [DETAIL_VIEW_QUERY_PARAM_NAME]: getIdFromGraphQLId(modalWorkItem?.id),
        }),
        replace: true,
      });
    },
    openInModal({ event, modalWorkItem, context }) {
      if (!this.workItemsAlphaEnabled || context === LINKED_ITEMS_ANCHOR || this.isDrawer) {
        return;
      }

      if (event) {
        event.preventDefault();

        this.updateUrl(modalWorkItem);
      }

      if (this.isModal) {
        this.$emit('update-modal', event, modalWorkItem);
        return;
      }

      this.modalWorkItemId = modalWorkItem.id;
      this.modalWorkItemIid = modalWorkItem.iid;
      this.modalWorkItemNamespaceFullPath = modalWorkItem?.reference?.replace(
        `#${modalWorkItem.iid}`,
        '',
      );
      this.$refs.modal.show();
    },
    openReportAbuseModal(reply) {
      if (this.isModal) {
        this.$emit('openReportAbuse', reply);
      } else {
        this.toggleReportAbuseModal(true, reply);
      }
    },
    toggleReportAbuseModal(isOpen, workItem = this.workItem) {
      this.isReportModalOpen = isOpen;
      this.reportedUrl = workItem.webUrl || workItem.url || {};
      this.reportedUserId = workItem.author ? getIdFromGraphQLId(workItem.author.id) : 0;
    },
    hideStickyHeader() {
      this.isStickyHeaderShowing = false;
    },
    showStickyHeader() {
      this.isStickyHeaderShowing = true;
    },
    updateDraft(type, value) {
      this.draftData[type] = value;
    },
    async updateWorkItem({ clearDraft } = {}) {
      this.updateInProgress = true;
      try {
        const {
          data: { workItemUpdate },
        } = await this.$apollo.mutate({
          mutation: updateWorkItemMutation,
          variables: {
            input: {
              id: this.workItem.id,
              title: this.draftData.title,
              descriptionWidget: {
                description: this.draftData.description,
              },
            },
          },
        });

        const { errors } = workItemUpdate;

        if (errors?.length) {
          this.updateError = errors.join('\n');
          throw new Error(this.updateError);
        }

        if (clearDraft) {
          clearDraft();
        }

        this.editMode = false;
      } catch (error) {
        Sentry.captureException(error);
      } finally {
        this.updateInProgress = false;
      }
    },
    cancelEditing() {
      this.draftData = {};
      this.editMode = false;
    },
    isValidDesignUpload(files) {
      if (!this.workspacePermissions.createDesign) return false;

      if (files.length > MAXIMUM_FILE_UPLOAD_LIMIT) {
        this.designUploadError = MAXIMUM_FILE_UPLOAD_LIMIT_REACHED;

        return false;
      }
      return true;
    },
    onUploadDesign(files) {
      // Redirect to latest version before uploading to avoid cache reading errors
      if (this.$route?.query?.version) {
        this.$router.push({
          path: this.$route.path,
          query: {},
        });
      }

      // convert to Array so that we have Array methods (.map, .some, etc.)
      this.filesToBeSaved = Array.from(files);
      if (!this.isValidDesignUpload(this.filesToBeSaved)) return null;

      const mutationPayload = {
        optimisticResponse: designUploadOptimisticResponse(this.filesToBeSaved),
        variables: {
          files: this.filesToBeSaved,
          projectPath: this.fullPath,
          iid: this.iid,
        },
        context: {
          hasUpload: true,
        },
        mutation: uploadDesignMutation,
        update: this.afterUploadDesign,
      };

      return this.$apollo
        .mutate(mutationPayload)
        .then((res) => this.onUploadDesignDone(res))
        .catch(() => this.onUploadDesignError());
    },
    afterUploadDesign(store, { data: { designManagementUpload } }) {
      updateStoreAfterUploadDesign(store, designManagementUpload, this.designCollectionQueryBody);
    },
    resetFilesToBeSaved() {
      this.filesToBeSaved = [];
    },
    onUploadDesignDone(res) {
      // display any warnings, if necessary
      const skippedFiles = res?.data?.designManagementUpload?.skippedDesigns || [];
      const skippedWarningMessage = designUploadSkippedWarning(this.filesToBeSaved, skippedFiles);
      if (skippedWarningMessage) {
        this.designUploadError = skippedWarningMessage;
      }

      // reset state
      this.resetFilesToBeSaved();
    },
    onUploadDesignError() {
      this.resetFilesToBeSaved();
      this.designUploadError = UPLOAD_DESIGN_ERROR_MESSAGE;
    },
    updateWorkItemCurrentTodosWidgetCache({ cache, todos }) {
      updateWorkItemCurrentTodosWidget({
        cache,
        todos,
        fullPath: this.workItemFullPath,
        iid: this.iid,
      });
    },
  },
  WORK_ITEM_TYPE_VALUE_OBJECTIVE,
  WORKSPACE_PROJECT,
  noAccessSvg,
};
</script>

<template>
  <div>
    <work-item-sticky-header
      v-if="showIntersectionObserver"
      :current-user-todos="currentUserTodos"
      :show-work-item-current-user-todos="showWorkItemCurrentUserTodos"
      :parent-work-item-confidentiality="parentWorkItemConfidentiality"
      :update-in-progress="updateInProgress"
      :full-path="workItemFullPath"
      :is-modal="isModal"
      :work-item="workItem"
      :is-sticky-header-showing="isStickyHeaderShowing"
      :work-item-notifications-subscribed="workItemNotificationsSubscribed"
      :work-item-author-id="workItemAuthorId"
      @hideStickyHeader="hideStickyHeader"
      @showStickyHeader="showStickyHeader"
      @deleteWorkItem="$emit('deleteWorkItem', { workItemType, workItemId: workItem.id })"
      @toggleWorkItemConfidentiality="toggleConfidentiality"
      @error="updateError = $event"
      @promotedToObjective="$emit('promotedToObjective', iid)"
      @toggleEditMode="enableEditMode"
      @workItemStateUpdated="$emit('workItemStateUpdated')"
      @toggleReportAbuseModal="toggleReportAbuseModal"
      @todosUpdated="updateWorkItemCurrentTodosWidgetCache"
    />
    <section class="work-item-view">
      <section v-if="updateError" class="flash-container flash-container-page sticky">
        <gl-alert class="gl-mb-3" variant="danger" @dismiss="updateError = undefined">
          {{ updateError }}
        </gl-alert>
      </section>
      <section :class="workItemBodyClass">
        <div :class="modalCloseButtonClass">
          <gl-button
            v-if="isModal"
            class="gl-ml-auto"
            category="tertiary"
            data-testid="work-item-close"
            icon="close"
            :aria-label="__('Close')"
            @click="$emit('close')"
          />
        </div>
        <work-item-loading v-if="workItemLoading" />
        <gl-empty-state
          v-else-if="error"
          :title="$options.i18n.fetchErrorTitle"
          :description="error"
          :svg-path="$options.noAccessSvg"
        />
        <div v-else data-testid="detail-wrapper">
          <div class="gl-block gl-flex-row gl-items-start gl-gap-3 sm:!gl-flex">
            <work-item-ancestors v-if="shouldShowAncestors" :work-item="workItem" class="gl-mb-1" />
            <div v-if="!error" :class="titleClassHeader" data-testid="work-item-type">
              <work-item-title
                v-if="workItem.title"
                ref="title"
                :is-editing="editMode"
                :title="workItem.title"
                @updateWorkItem="updateWorkItem"
                @updateDraft="updateDraft('title', $event)"
                @error="updateError = $event"
              />
            </div>
            <div class="gl-ml-auto gl-mt-1 gl-flex gl-gap-3 gl-self-start">
              <gl-button
                v-if="shouldShowEditButton"
                category="secondary"
                data-testid="work-item-edit-form-button"
                class="shortcut-edit-wi-description"
                @click="enableEditMode"
              >
                {{ __('Edit') }}
              </gl-button>
              <todos-toggle
                v-if="showWorkItemCurrentUserTodos"
                :item-id="workItem.id"
                :current-user-todos="currentUserTodos"
                todos-button-type="secondary"
                @todosUpdated="updateWorkItemCurrentTodosWidgetCache"
                @error="updateError = $event"
              />
              <work-item-notifications-widget
                v-if="newTodoAndNotificationsEnabled"
                :full-path="workItemFullPath"
                :work-item-id="workItem.id"
                :subscribed-to-notifications="workItemNotificationsSubscribed"
                :can-update="canUpdate"
                @error="updateError = $event"
              />
              <work-item-actions
                v-if="workItemPresent"
                :full-path="workItemFullPath"
                :work-item-id="workItem.id"
                :hide-subscribe="newTodoAndNotificationsEnabled"
                :subscribed-to-notifications="workItemNotificationsSubscribed"
                :work-item-type="workItemType"
                :work-item-type-id="workItemTypeId"
                :work-item-iid="iid"
                :can-delete="canDelete"
                :can-update="canUpdate"
                :is-confidential="workItem.confidential"
                :is-discussion-locked="isDiscussionLocked"
                :is-parent-confidential="parentWorkItemConfidentiality"
                :work-item-reference="workItem.reference"
                :work-item-create-note-email="workItem.createNoteEmail"
                :is-modal="isModal"
                :work-item-state="workItem.state"
                :has-children="hasChildren"
                :work-item-author-id="workItemAuthorId"
                :can-create-related-item="workItemLinkedItems !== undefined"
                @deleteWorkItem="$emit('deleteWorkItem', { workItemType, workItemId: workItem.id })"
                @toggleWorkItemConfidentiality="toggleConfidentiality"
                @error="updateError = $event"
                @promotedToObjective="$emit('promotedToObjective', iid)"
                @workItemStateUpdated="$emit('workItemStateUpdated')"
                @toggleReportAbuseModal="toggleReportAbuseModal"
              />
            </div>
            <gl-button
              v-if="isModal"
              class="gl-hidden sm:!gl-block"
              category="tertiary"
              data-testid="work-item-close"
              icon="close"
              :aria-label="__('Close')"
              @click="$emit('close')"
            />
          </div>
          <div :class="{ 'gl-mt-3': !editMode }">
            <work-item-title
              v-if="workItem.title && shouldShowAncestors"
              ref="title"
              :is-editing="editMode"
              :class="titleClassComponent"
              :title="workItem.title"
              @error="updateError = $event"
              @updateWorkItem="updateWorkItem"
              @updateDraft="updateDraft('title', $event)"
            />
            <work-item-created-updated
              v-if="!editMode"
              :full-path="workItemFullPath"
              :work-item-iid="iid"
              :update-in-progress="updateInProgress"
            />
          </div>
          <div data-testid="work-item-overview" class="work-item-overview">
            <section>
              <work-item-description
                v-if="hasDescriptionWidget"
                :edit-mode="editMode"
                :full-path="workItemFullPath"
                :work-item-id="workItem.id"
                :work-item-iid="workItem.iid"
                :update-in-progress="updateInProgress"
                :without-heading-anchors="isDrawer"
                @updateWorkItem="updateWorkItem"
                @updateDraft="updateDraft('description', $event)"
                @cancelEditing="cancelEditing"
                @error="updateError = $event"
              />
              <div class="gl-flex gl-flex-col gl-flex-wrap sm:gl-flex-row sm:gl-gap-5">
                <work-item-award-emoji
                  v-if="workItemAwardEmoji"
                  :work-item-id="workItem.id"
                  :work-item-fullpath="workItemFullPath"
                  :award-emoji="workItemAwardEmoji.awardEmoji"
                  :work-item-iid="iid"
                  @error="updateError = $event"
                  @emoji-updated="$emit('work-item-emoji-updated', $event)"
                />
                <design-upload-button
                  v-if="showUploadDesign"
                  :is-saving="isSaving"
                  data-testid="design-upload-button"
                  @upload="onUploadDesign"
                />
              </div>
            </section>
            <aside
              data-testid="work-item-overview-right-sidebar"
              class="work-item-overview-right-sidebar"
              :class="{ 'is-modal': isModal }"
            >
              <work-item-attributes-wrapper
                :class="{ 'gl-top-11': isDrawer }"
                :full-path="workItemFullPath"
                :work-item="workItem"
                :group-path="groupPath"
                :is-group="isGroupWorkItem"
                @error="updateError = $event"
                @attributesUpdated="$emit('attributesUpdated', $event)"
              />
            </aside>

            <design-widget
              v-if="hasDesignWidget"
              :class="{ 'gl-mt-0': isDrawer }"
              :work-item-id="workItem.id"
              :work-item-iid="iid"
              :upload-error="designUploadError"
              @dismissError="designUploadError = null"
            />

            <work-item-tree
              v-if="showWorkItemTree"
              :full-path="workItemFullPath"
              :is-group="isGroupWorkItem"
              :work-item-type="workItemType"
              :parent-work-item-type="workItem.workItemType.name"
              :work-item-id="workItem.id"
              :work-item-iid="iid"
              :can-update="canUpdate"
              :can-update-children="canUpdateChildren"
              :confidential="workItem.confidential"
              :allowed-child-types="allowedChildTypes"
              :is-drawer="isDrawer"
              @show-modal="openInModal"
              @addChild="$emit('addChild')"
              @childrenLoaded="hasChildren = $event"
            />
            <work-item-relationships
              v-if="workItemLinkedItems"
              :is-group="isGroupWorkItem"
              :work-item-id="workItem.id"
              :work-item-iid="iid"
              :work-item-full-path="workItemFullPath"
              :work-item-type="workItem.workItemType.name"
              :can-admin-work-item-link="canAdminWorkItemLink"
              @showModal="openInModal"
            />
            <work-item-notes
              v-if="workItemNotes"
              :full-path="workItemFullPath"
              :work-item-id="workItem.id"
              :work-item-iid="workItem.iid"
              :work-item-type="workItemType"
              :is-modal="isModal"
              :assignees="workItemAssignees && workItemAssignees.assignees.nodes"
              :can-set-work-item-metadata="canAssignUnassignUser"
              :report-abuse-path="reportAbusePath"
              :is-discussion-locked="isDiscussionLocked"
              :is-work-item-confidential="workItem.confidential"
              class="gl-pt-5"
              :use-h2="!isModal"
              @error="updateError = $event"
              @openReportAbuse="openReportAbuseModal"
            />
          </div>
        </div>
      </section>
    </section>
    <work-item-detail-modal
      v-if="!isModal && !isDrawer"
      ref="modal"
      :parent-id="workItem.id"
      :work-item-id="modalWorkItemId"
      :work-item-iid="modalWorkItemIid"
      :work-item-full-path="modalWorkItemNamespaceFullPath"
      :show="true"
      @close="updateUrl"
      @openReportAbuse="toggleReportAbuseModal(true, $event)"
    />
    <work-item-abuse-modal
      v-if="isReportModalOpen"
      :show-modal="isReportModalOpen"
      :reported-user-id="reportedUserId"
      :reported-from-url="reportedUrl"
      @close-modal="toggleReportAbuseModal(false)"
    />
  </div>
</template>
