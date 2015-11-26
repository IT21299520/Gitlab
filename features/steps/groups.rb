class Spinach::Features::Groups < Spinach::FeatureSteps
  include SharedAuthentication
  include SharedPaths
  include SharedGroup
  include SharedUser
  include Select2Helper

  step 'I should see back to dashboard button' do
    expect(page).to have_content 'Go to dashboard'
  end

  step 'gitlab user "Mike"' do
    create(:user, name: "Mike")
  end

  step 'I should see group "Owned"' do
    expect(page).to have_content '@owned'
  end

  step 'I am a signed out user' do
    logout
  end

  step 'Group "Owned" has a public project "Public-project"' do
    group = owned_group

    @project = create :empty_project, :public,
                 group: group,
                 name: "Public-project"
  end

  step 'I should see project "Public-project"' do
    expect(page).to have_content 'Public-project'
  end

  step 'I select "Mike" as "Reporter"' do
    user = User.find_by(name: "Mike")

    page.within ".users-group-form" do
      select2(user.id, from: "#user_ids", multiple: true)
      select "Reporter", from: "access_level"
    end

    click_button "Add users to group"
  end

  step 'I select "Mike" as "Master"' do
    user = User.find_by(name: "Mike")

    page.within ".users-group-form" do
      select2(user.id, from: "#user_ids", multiple: true)
      select "Master", from: "access_level"
    end

    click_button "Add users to group"
  end

  step 'I should see "Mike" in team list as "Reporter"' do
    page.within '.content-list' do
      expect(page).to have_content('Mike')
      expect(page).to have_content('Reporter')
    end
  end

  step 'I should see "Mike" in team list as "Owner"' do
    page.within '.content-list' do
      expect(page).to have_content('Mike')
      expect(page).to have_content('Owner')
    end
  end

  step 'I select "sjobs@apple.com" as "Reporter"' do
    page.within ".users-group-form" do
      select2("sjobs@apple.com", from: "#user_ids", multiple: true)
      select "Reporter", from: "access_level"
    end

    click_button "Add users to group"
  end

  step 'I should see "sjobs@apple.com" in team list as invited "Reporter"' do
    page.within '.content-list' do
      expect(page).to have_content('sjobs@apple.com')
      expect(page).to have_content('invited')
      expect(page).to have_content('Reporter')
    end
  end

  step 'I should see group "Owned" projects list' do
    owned_group.projects.each do |project|
      expect(page).to have_link project.name
    end
  end

  step 'I should see projects activity feed' do
    expect(page).to have_content 'closed issue'
  end

  step 'I should see issues from group "Owned" assigned to me' do
    assigned_to_me(:issues).each do |issue|
      expect(page).to have_content issue.title
    end
  end

  step 'I should see merge requests from group "Owned" assigned to me' do
    assigned_to_me(:merge_requests).each do |issue|
      expect(page).to have_content issue.title[0..80]
    end
  end

  step 'I select user "Mary Jane" from list with role "Reporter"' do
    user = User.find_by(name: "Mary Jane") || create(:user, name: "Mary Jane")

    page.within ".users-group-form" do
      select2(user.id, from: "#user_ids", multiple: true)
      select "Reporter", from: "access_level"
    end

    click_button "Add users to group"
  end

  step 'I should see user "John Doe" in team list' do
    expect(group_members_list).to have_content("John Doe")
  end

  step 'I should not see user "John Doe" in team list' do
    expect(group_members_list).not_to have_content("John Doe")
  end

  step 'I should see user "Mary Jane" in team list' do
    expect(group_members_list).to have_content("Mary Jane")
  end

  step 'I should not see user "Mary Jane" in team list' do
    expect(group_members_list).not_to have_content("Mary Jane")
  end

  step 'project from group "Owned" has issues assigned to me' do
    create :issue,
      project: project,
      assignee: current_user,
      author: current_user
  end

  step 'project from group "Owned" has merge requests assigned to me' do
    create :merge_request,
      source_project: project,
      target_project: project,
      assignee: current_user,
      author: current_user
  end

  step 'I change group "Owned" name to "new-name"' do
    fill_in 'group_name', with: 'new-name'
    fill_in 'group_path', with: 'new-name'
    click_button "Save group"
  end

  step 'I should see new group "Owned" name' do
    page.within ".navbar-gitlab" do
      expect(page).to have_content "new-name"
    end
  end

  step 'I change group "Owned" avatar' do
    attach_file(:group_avatar, File.join(Rails.root, 'spec', 'fixtures', 'banana_sample.gif'))
    click_button "Save group"
    owned_group.reload
  end

  step 'I should see new group "Owned" avatar' do
    expect(owned_group.avatar).to be_instance_of AvatarUploader
    expect(owned_group.avatar.url).to eq "/uploads/group/avatar/#{ Group.find_by(name:"Owned").id }/banana_sample.gif"
  end

  step 'I should see the "Remove avatar" button' do
    expect(page).to have_link("Remove avatar")
  end

  step 'I have group "Owned" avatar' do
    attach_file(:group_avatar, File.join(Rails.root, 'spec', 'fixtures', 'banana_sample.gif'))
    click_button "Save group"
    owned_group.reload
  end

  step 'I remove group "Owned" avatar' do
    click_link "Remove avatar"
    owned_group.reload
  end

  step 'I should not see group "Owned" avatar' do
    expect(owned_group.avatar?).to eq false
  end

  step 'I should not see the "Remove avatar" button' do
    expect(page).not_to have_link("Remove avatar")
  end

  step 'I click on the "Remove User From Group" button for "John Doe"' do
    find(:css, 'li', text: "John Doe").find(:css, 'a.btn-remove').click
    # poltergeist always confirms popups.
  end

  step 'I click on the "Remove User From Group" button for "Mary Jane"' do
    find(:css, 'li', text: "Mary Jane").find(:css, 'a.btn-remove').click
    # poltergeist always confirms popups.
  end

  step 'I should not see the "Remove User From Group" button for "John Doe"' do
    expect(find(:css, 'li', text: "John Doe")).not_to have_selector(:css, 'a.btn-remove')
    # poltergeist always confirms popups.
  end

  step 'I should not see the "Remove User From Group" button for "Mary Jane"' do
    expect(find(:css, 'li', text: "Mary Jane")).not_to have_selector(:css, 'a.btn-remove')
    # poltergeist always confirms popups.
  end

  step 'I search for \'Mary\' member' do
    page.within '.member-search-form' do
      fill_in 'search', with: 'Mary'
      click_button 'Search'
    end
  end

  step 'I click on group milestones' do
    click_link 'Milestones'
  end

  step 'I should see group milestones index page has no milestones' do
    expect(page).to have_content('No milestones to show')
  end

  step 'Group has projects with milestones' do
    group_milestone
  end

  step 'I should see group milestones index page with milestones' do
    expect(page).to have_content('Version 7.2')
    expect(page).to have_content('GL-113')
    expect(page).to have_link('2 Issues', href: issues_group_path("owned", milestone_title: "Version 7.2"))
    expect(page).to have_link('3 Merge Requests', href: merge_requests_group_path("owned", milestone_title: "GL-113"))
  end

  step 'I click on one group milestone' do
    click_link 'GL-113'
  end

  step 'I should see group milestone with descriptions and expiry date' do
    expect(page).to have_content('expires at Aug 20, 2114')
  end

  step 'I should see group milestone with all issues and MRs assigned to that milestone' do
    expect(page).to have_content('Milestone GL-113')
    expect(page).to have_content('Progress: 0 closed – 4 open')
    expect(page).to have_link(@issue1.title, href: namespace_project_issue_path(@project1.namespace, @project1, @issue1))
    expect(page).to have_link(@mr3.title, href: namespace_project_merge_request_path(@project3.namespace, @project3, @mr3))
  end

  step 'Group "Owned" has archived project' do
    group = Group.find_by(name: 'Owned')
    create(:project, namespace: group, archived: true, path: "archived-project")
  end

  step 'I should see "archived" label' do
    expect(page).to have_xpath("//span[@class='label label-warning']", text: 'archived')
  end

  step 'I fill milestone name' do
    fill_in 'milestone_title', with: 'v2.9.0'
  end

  step 'I click new milestone button' do
    click_link "New Milestone"
  end

  step 'I press create mileston button' do
    click_button "Create Milestone"
  end

  step 'milestone in each project should be created' do
    group = Group.find_by(name: 'Owned')
    expect(page).to have_content "Milestone v2.9.0"
    expect(group.projects).to be_present

    group.projects.each do |project|
      expect(page).to have_content project.name
    end
  end

  step 'I change the "Mary Jane" role to "Developer"' do
    member = mary_jane_member

    page.within "#group_member_#{member.id}" do
      find(".js-toggle-button").click
      page.within "#edit_group_member_#{member.id}" do
        select 'Developer', from: 'group_member_access_level'
        click_on 'Save'
      end
    end
  end

  step 'I should see "Mary Jane" as "Developer"' do
    member = mary_jane_member

    page.within "#group_member_#{member.id}" do
      page.within '.member-access-level' do
        expect(page).to have_content "Developer"
      end
    end
  end

  protected

  def owned_group
    @owned_group ||= Group.find_by(name: "Owned")
  end

  def mary_jane_member
    user = User.find_by(name: "Mary Jane")
    owned_group.members.find_by(user_id: user.id)
  end

  def assigned_to_me(key)
    project.send(key).where(assignee_id: current_user.id)
  end

  def project
    owned_group.projects.first
  end

  def group_milestone
    group = owned_group

    %w(gitlabhq gitlab-ci cookbook-gitlab).each do |path|
      project = create :project, path: path, group: group
      milestone = create :milestone, title: "Version 7.2", project: project
      create :issue,
        project: project,
        assignee: current_user,
        author: current_user,
        milestone: milestone

      milestone = create :milestone, title: "GL-113", project: project
      create :issue,
        project: project,
        assignee: current_user,
        author: current_user,
        milestone: milestone
    end
  end

  def group_members_list
    find(".panel .content-list")
  end
end
