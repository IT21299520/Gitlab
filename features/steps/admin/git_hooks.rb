require 'webmock'

class Spinach::Features::AdminGitHooksSample < Spinach::FeatureSteps
  include SharedAuthentication
  include SharedProject
  include SharedPaths
  include RSpec::Matchers
  include RSpec::Mocks::ExampleMethods
  include WebMock::API

  step 'I fill in a form and submit' do
    fill_in "Commit message", with: "my_string"
    click_button "Save Git hooks"
  end

  step 'I see my git hook saved' do
    visit admin_git_hooks_path
    expect(page).to have_selector("input[value='my_string']")
  end
end
