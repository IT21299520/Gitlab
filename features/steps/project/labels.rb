class ProjectLabels < Spinach::FeatureSteps
  include SharedAuthentication
  include SharedProject
  include SharedPaths

  step 'I should see label "bug"' do
    within ".manage-labels-list" do
      page.should have_content "bug"
    end
  end

  step 'I should see label "feature"' do
    within ".manage-labels-list" do
      page.should have_content "feature"
    end
  end

  step 'I visit \'bug\' label edit page' do
    visit edit_project_label_path(project, bug_label)
  end

  step 'I remove label \'bug\'' do
    within "#label_#{bug_label.id}" do
      click_link 'Remove'
    end
  end

  step 'I submit new label \'support\'' do
    fill_in 'Title', with: 'support'
    fill_in 'Background Color', with: '#F95610'
    click_button 'Save'
  end

  step 'I submit new label without color' do
    fill_in 'Title', with: 'support'
    click_button 'Save'
  end

  step 'I submit new label without name' do
    fill_in 'Background Color', with: '#F95610'
    click_button 'Save'
  end

  step 'I should see label color error message' do
    within '.label-form' do
      page.should have_content 'Color is invalid'
    end
  end

  step 'I should see label title error message' do
    within '.label-form' do
      page.should have_content "Title can't be blank"
    end
  end

  step 'I should not see label \'bug\'' do
    within '.manage-labels-list' do
      page.should_not have_content 'bug'
    end
  end

  step 'I should see label \'support\'' do
    within '.manage-labels-list' do
      page.should have_content 'support'
    end
  end

  step 'I change label \'bug\' to \'fix\'' do
    fill_in 'Title', with: 'fix'
    fill_in 'Background Color', with: '#F15610'
    click_button 'Save'
  end

  step 'I should see label \'fix\'' do
    within '.manage-labels-list' do
      page.should have_content 'fix'
    end
  end

  def bug_label
    project.labels.find_or_create_by(title: 'bug')
  end
end
