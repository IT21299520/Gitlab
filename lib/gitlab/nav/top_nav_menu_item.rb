# frozen_string_literal: true

module Gitlab
  module Nav
    class TopNavMenuItem
      # We want to have all keyword arguments for type safety.
      # Ordinarily we could introduce a params object, but that's kind of what
      # this is already :/. We could also take a hash and manually check every
      # entry, but it's much more maintainable to do rely on native Ruby.
      # rubocop: disable Metrics/ParameterLists
      def self.build(
        id:, title:, active: false, icon: '', href: '', view: '',
        css_class: nil, data: nil, partial: nil, component: nil
      )
        {
          id: id,
          type: :item,
          title: title,
          active: active,
          icon: icon,
          href: href,
          view: view.to_s,
          css_class: css_class,
          data: data || { testid: 'menu_item_link', qa_title: title },
          partial: partial,
          component: component
        }
      end
      # rubocop: enable Metrics/ParameterLists
    end
  end
end
