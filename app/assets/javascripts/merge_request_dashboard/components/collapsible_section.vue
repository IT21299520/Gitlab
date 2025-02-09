<script>
import { GlButton, GlBadge, GlTooltipDirective } from '@gitlab/ui';
import { __, sprintf } from '~/locale';

export default {
  components: {
    GlButton,
    GlBadge,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    title: {
      type: String,
      required: true,
    },
    helpContent: {
      type: String,
      required: false,
      default: '',
    },
    count: {
      type: Number,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      open: true,
    };
  },
  computed: {
    toggleButtonIcon() {
      return this.open ? 'chevron-down' : 'chevron-right';
    },
    toggleButtonLabel() {
      return sprintf(
        this.open
          ? __('Collapse %{section} merge requests')
          : __('Expand %{section} merge requests'),
        {
          section: this.title.toLowerCase(),
        },
      );
    },
  },
  watch: {
    count: {
      handler(newVal) {
        this.open = newVal > 0;
      },
      immediate: true,
    },
  },
  methods: {
    toggleOpen() {
      this.open = !this.open;
    },
  },
};
</script>

<template>
  <div>
    <section class="gl-border gl-rounded-base">
      <header
        :class="{ 'gl-rounded-base': !open }"
        class="gl-rounded-tl-base gl-rounded-tr-base gl-bg-gray-10 gl-px-5 gl-py-4"
      >
        <h2 class="h5 gl-m-0">
          <gl-button
            :icon="toggleButtonIcon"
            size="small"
            category="tertiary"
            class="gl-mr-2"
            :aria-label="toggleButtonLabel"
            :disabled="count === 0"
            data-testid="section-toggle-button"
            @click="toggleOpen"
          />
          {{ title }}
          <gl-badge
            v-if="count !== null"
            class="gl-ml-1"
            variant="neutral"
            size="sm"
            data-testid="merge-request-list-count"
            >{{ count }}</gl-badge
          >
          <gl-button
            v-gl-tooltip
            :title="helpContent"
            icon="information-o"
            variant="link"
            class="gl-relative gl-top-2 gl-float-right gl-inline-flex"
          />
        </h2>
      </header>
      <div v-if="open" data-testid="section-content">
        <slot></slot>
      </div>
    </section>
    <slot v-if="open" name="pagination"></slot>
  </div>
</template>
