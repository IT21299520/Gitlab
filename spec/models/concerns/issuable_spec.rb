require 'spec_helper'

describe Issue, "Issuable" do
  let(:issue) { create(:issue) }

  describe "Associations" do
    it { should belong_to(:project) }
    it { should belong_to(:author) }
    it { should belong_to(:assignee) }
    it { should have_many(:notes).dependent(:destroy) }
  end

  describe "Validation" do
    before { subject.stub(set_iid: false) }
    it { should validate_presence_of(:project) }
    it { should validate_presence_of(:iid) }
    it { should validate_presence_of(:author) }
    it { should validate_presence_of(:title) }
    it { should ensure_length_of(:title).is_at_least(0).is_at_most(255) }
  end

  describe "Scope" do
    it { expect(described_class).to respond_to(:opened) }
    it { expect(described_class).to respond_to(:closed) }
    it { expect(described_class).to respond_to(:assigned) }
  end

  describe ".search" do
    let!(:searchable_issue) { create(:issue, title: "Searchable issue") }

    it "matches by title" do
      expect(described_class.search('able')).to eq([searchable_issue])
    end
  end

  describe "#today?" do
    it "returns true when created today" do
      # Avoid timezone differences and just return exactly what we want
      allow(Date).to receive(:today).and_return(issue.created_at.to_date)
      expect(issue.today?).to be_true
    end

    it "returns false when not created today" do
      allow(Date).to receive(:today).and_return(Date.yesterday)
      expect(issue.today?).to be_false
    end
  end

  describe "#new?" do
    it "returns true when created today and record hasn't been updated" do
      allow(issue).to receive(:today?).and_return(true)
      expect(issue.new?).to be_true
    end

    it "returns false when not created today" do
      allow(issue).to receive(:today?).and_return(false)
      expect(issue.new?).to be_false
    end

    it "returns false when record has been updated" do
      allow(issue).to receive(:today?).and_return(true)
      issue.touch
      expect(issue.new?).to be_false
    end
  end
end
