<!-- eslint-disable vue/multi-word-component-names -->
<script>
import {
  GlButton,
  GlIcon,
  GlDisclosureDropdown,
  GlSearchBoxByType,
  GlTooltipDirective,
} from '@gitlab/ui';
import { findLastIndex } from 'lodash';
import VirtualList from 'vue-virtual-scroll-list';
import { getEmojiCategoryMap, state } from '~/emoji';
import { __ } from '~/locale';
import { CATEGORY_NAMES, CATEGORY_ICON_MAP, FREQUENTLY_USED_KEY } from '../constants';
import Category from './category.vue';
import EmojiList from './emoji_list.vue';
import { addToFrequentlyUsed, getEmojiCategories, hasFrequentlyUsedEmojis } from './utils';

export default {
  components: {
    GlButton,
    GlIcon,
    GlDisclosureDropdown,
    GlSearchBoxByType,
    VirtualList,
    Category,
    EmojiList,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: {
    newCustomEmojiPath: {
      default: '',
    },
  },
  props: {
    toggleClass: {
      type: [Array, String, Object],
      required: false,
      default: () => [],
    },
    dropdownClass: {
      type: [Array, String, Object],
      required: false,
      default: () => [],
    },
    right: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  data() {
    return {
      isVisible: false,
      currentCategory: 0,
      searchValue: '',
    };
  },
  computed: {
    categoryNames() {
      return CATEGORY_NAMES.filter((c) => {
        if (c === FREQUENTLY_USED_KEY) return hasFrequentlyUsedEmojis();
        if (c === 'custom') return !state.loading && getEmojiCategoryMap().custom.length > 0;
        return true;
      }).map((category) => ({
        name: category,
        icon: CATEGORY_ICON_MAP[category],
      }));
    },
    placement() {
      return this.right ? 'bottom-end' : 'bottom-start';
    },
    newCustomEmoji() {
      return {
        text: __('Create new emoji'),
        href: this.newCustomEmojiPath,
        extraAttrs: {
          'data-testid': 'create-new-emoji',
        },
      };
    },
  },
  methods: {
    categoryAppeared(category) {
      this.currentCategory = category;
    },
    async scrollToCategory(categoryName) {
      const categories = await getEmojiCategories();
      const { top } = categories[categoryName];

      this.$refs.virtualScoller.setScrollTop(top);
    },
    selectEmoji({ category, emoji }) {
      this.$emit('click', emoji);
      this.$refs.dropdown.close();

      if (category !== 'custom') {
        addToFrequentlyUsed(emoji);
      }
    },
    onSearchInput() {
      if (this.$refs.virtualScoller) {
        this.$refs.virtualScoller.setScrollTop(0);
        this.$refs.virtualScoller.forceRender();
      }
    },
    async onScroll(event, { offset }) {
      const categories = await getEmojiCategories();

      this.currentCategory = findLastIndex(Object.values(categories), ({ top }) => offset >= top);
    },
    onShow() {
      this.isVisible = true;
      this.$emit('shown');
    },
    onHide() {
      this.isVisible = false;
      this.currentCategory = 0;
      this.searchValue = '';
      this.$emit('hidden');
    },
  },
  i18n: {
    addReaction: __('Add reaction'),
    createEmoji: __('Create new emoji'),
  },
};
</script>

<template>
  <div class="emoji-picker">
    <gl-disclosure-dropdown
      ref="dropdown"
      :class="dropdownClass"
      :placement="placement"
      @shown="onShow"
      @hidden="onHide"
    >
      <template #toggle>
        <gl-button
          v-gl-tooltip
          :title="$options.i18n.addReaction"
          :class="[toggleClass, { 'is-active': isVisible }]"
          class="add-reaction-button btn-icon gl-relative gl-h-full"
          data-testid="add-reaction-button"
        >
          <slot name="button-content">
            <span class="reaction-control-icon reaction-control-icon-neutral">
              <gl-icon class="award-control-icon-neutral gl-button-icon" name="slight-smile" />
            </span>
            <span class="reaction-control-icon reaction-control-icon-positive">
              <gl-icon
                class="award-control-icon-positive gl-button-icon !gl-left-3"
                name="smiley"
              />
            </span>
            <span class="reaction-control-icon reaction-control-icon-super-positive">
              <gl-icon
                class="award-control-icon-super-positive gl-button-icon !gl-left-3"
                name="smile"
              />
            </span>
          </slot>
        </gl-button>
      </template>

      <template v-if="isVisible" #header>
        <gl-search-box-by-type
          ref="searchValue"
          v-model="searchValue"
          class="add-reaction-search gl-border-b-1 gl-border-b-dropdown gl-border-b-solid"
          borderless
          autofocus
          debounce="500"
          :aria-label="__('Search for an emoji')"
          @input="onSearchInput"
        />
      </template>

      <div
        v-if="isVisible"
        v-show="!searchValue"
        class="award-list gl-flex gl-border-b-1 gl-border-gray-100 gl-border-b-solid"
      >
        <gl-button
          v-for="(category, index) in categoryNames"
          :key="category.name"
          category="tertiary"
          :class="{ 'emoji-picker-category-active': index === currentCategory }"
          class="emoji-picker-category-tab gl-grow !gl-rounded-none !gl-border-b-2 !gl-px-3 !gl-border-b-solid"
          :icon="category.icon"
          :aria-label="category.name"
          @click="scrollToCategory(category.name)"
          @keydown.enter="scrollToCategory(category.name)"
        />
      </div>
      <emoji-list v-if="isVisible" :search-value="searchValue">
        <template #default="{ filteredCategories }">
          <virtual-list
            ref="virtualScoller"
            :size="258"
            :remain="1"
            :bench="2"
            variable
            :onscroll="onScroll"
          >
            <div
              v-for="(category, categoryKey) in filteredCategories"
              :key="categoryKey"
              :style="{ height: category.height + 'px' }"
            >
              <category :category="categoryKey" :emojis="category.emojis" @click="selectEmoji" />
            </div>
          </virtual-list>
        </template>
      </emoji-list>

      <template v-if="newCustomEmojiPath" #footer>
        <div
          class="gl-flex gl-flex-col gl-border-t-1 gl-border-t-dropdown !gl-p-2 !gl-pt-0 gl-border-t-solid"
        >
          <gl-button
            :href="newCustomEmojiPath"
            category="tertiary"
            block
            data-testid="create-new-emoji"
            class="!gl-mt-2 !gl-justify-start"
          >
            {{ $options.i18n.createEmoji }}
          </gl-button>
        </div>
      </template>
    </gl-disclosure-dropdown>
  </div>
</template>
