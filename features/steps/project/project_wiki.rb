class ProjectWiki < Spinach::FeatureSteps
  include SharedAuthentication
  include SharedProject
  include SharedNote
  include SharedPaths

  Given 'I create Wiki page' do
    fill_in "Title", :with => 'Test title'
    #fill_in "epiceditor-editor", :with => '[link test](test)...'
    find("#epiceditor-editos").native.send_keys '[link test](test)'
    click_on "Save"
  end

  Then 'I should see newly created wiki page' do
    page.should have_content "Test title"
    page.should have_content "link test"

    click_link "link test"
    page.should have_content "Editing page"
  end
end
