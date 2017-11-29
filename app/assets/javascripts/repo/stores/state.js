export default () => ({
  canCommit: false,
  changedFiles: [],
  currentBranch: '',
  currentBlobView: 'repo-preview',
  currentRef: '',
  editMode: false,
  endpoints: {},
  isRoot: false,
  isInitialRoot: false,
  lastCommitPath: '',
  loading: false,
  onTopOfBranch: false,
  openFiles: [],
  path: '',
  project: {
    id: 0,
    name: '',
    url: '',
  },
  parentTreeUrl: '',
  previousUrl: '',
  tree: [],
});
