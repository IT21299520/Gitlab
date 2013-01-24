require 'spec_helper'

describe CommitsController do
  let(:project) { create(:project) }
  let(:user)    { create(:user) }

  before do
    sign_in(user)
    project.team << [user, :master]
  end

  describe "GET show" do
    context "as atom feed" do
      it "should render as atom" do
        get :show, project_id: project.path, id: "master.atom"
        expect(response).to be_success
        expect(response.content_type).to eq('application/atom+xml')
      end
    end
  end
end