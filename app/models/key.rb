# == Schema Information
#
# Table name: keys
#
#  id          :integer          not null, primary key
#  user_id     :integer
#  created_at  :datetime
#  updated_at  :datetime
#  key         :text
#  title       :string(255)
#  type        :string(255)
#  fingerprint :string(255)
#

require 'digest/md5'

class Key < ActiveRecord::Base
  include Sortable
  include Gitlab::Popen

  belongs_to :user

  before_validation :strip_white_space, :generate_fingerprint

  validates :title, presence: true, length: { within: 0..255 }
  validates :key, presence: true, length: { within: 0..5000 }, format: { with: /\A(ssh|ecdsa)-.*\Z/ }, uniqueness: true
  validates :fingerprint, uniqueness: true, presence: { message: 'cannot be generated' }

  delegate :name, :email, to: :user, prefix: true

  after_create :add_to_shell
  after_create :notify_user
  after_create :post_create_hook
  after_destroy :remove_from_shell
  after_destroy :post_destroy_hook

  def strip_white_space
    self.key = key.strip unless key.blank?
  end

  # projects that has this key
  def projects
    user.authorized_projects
  end

  def shell_id
    "key-#{id}"
  end

  def add_to_shell
    GitlabShellWorker.perform_async(
      :add_key,
      shell_id,
      key
    )
  end

  def notify_user
    NotificationService.new.new_key(self)
  end

  def post_create_hook
    SystemHooksService.new.execute_hooks_for(self, :create)
  end

  def remove_from_shell
    GitlabShellWorker.perform_async(
      :remove_key,
      shell_id,
      key,
    )
  end

  def post_destroy_hook
    SystemHooksService.new.execute_hooks_for(self, :destroy)
  end

  private

  def generate_fingerprint
    self.fingerprint = nil
    return unless key.present?

    cmd_status = 0
    cmd_output = ''
    explicit_fingerprint_algorithm = false
    Tempfile.open('gitlab_key_file') do |file|
      file.puts key
      file.rewind

      # OpenSSH 6.8 introduces a new default output format for fingerprints.
      # Check the version and decide which command to use.
      version_output, version_status = popen(%W(ssh -V))
      if version_status.zero?
        out, _ = version_output.scan /.*?(\d)\.(\d).*?,/
        major, minor = out[0], out[1]
        if major.to_i > 6 or (major.to_i == 6 and minor.to_i >= 8)
          explicit_fingerprint_algorithm = true
        end
      end

      if explicit_fingerprint_algorithm
        cmd_output, cmd_status = popen(%W(ssh-keygen -E md5 -lf #{file.path}), '/tmp')
      else
        cmd_output, cmd_status = popen(%W(ssh-keygen -lf #{file.path}), '/tmp')
      end
    end

    if cmd_status.zero?
      if explicit_fingerprint_algorithm
        cmd_output.gsub /(MD5:)(\h{2}:)+\h{2}/ do |match|
          match.slice! /^MD5:/
          self.fingerprint = match
        end
      else
        cmd_output.gsub /(\h{2}:)+\h{2}/ do |match|
          self.fingerprint = match
        end
      end
    end
  end
end
