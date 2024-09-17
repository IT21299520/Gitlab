# frozen_string_literal: true

module Import
  module BulkImports
    module Common
      module Transformers
        class SourceUserMemberAttributesTransformer
          def transform(context, data)
            return data if !context.importer_user_mapping_enabled? || data.nil?

            # Create source_user and placeholder user if they do not exists so
            # they can be mapped to contributions in subsequent pipelines
            source_user = find_or_create_source_user(context, data)

            # For now, members are only created on subsequent imports for users
            # that have accepted the reassignment.
            # https://gitlab.com/gitlab-org/gitlab/-/issues/477845 will handle
            # membership for source_users mapped to placeholder users
            return unless source_user.accepted_status?

            access_level = data.dig('access_level', 'integer_value')
            return unless valid_access_level?(access_level)

            {
              user_id: source_user.mapped_user_id,
              access_level: access_level,
              created_at: data['created_at'],
              updated_at: data['updated_at'],
              expires_at: data['expires_at'],
              created_by_id: context.current_user.id
            }
          end

          private

          def valid_access_level?(access_level)
            Gitlab::Access.options_with_owner.value?(access_level)
          end

          def find_or_create_source_user(context, data)
            gid = data.dig('user', 'user_gid')

            source_user_id = GlobalID.parse(gid).model_id
            source_name = data.dig('user', 'name')
            source_username = data.dig('user', 'username')

            context.source_user_mapper.find_or_create_source_user(
              source_user_identifier: source_user_id,
              source_name: source_name,
              source_username: source_username
            )
          end
        end
      end
    end
  end
end
