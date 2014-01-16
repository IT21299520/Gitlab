#
# * Filter merge requests
#
@merge_requestsPage = ->
  $('#milestone_id, #assignee_id').select2().on 'change', ->
    $(this).closest('form').submit()

class MergeRequest

  constructor: (@opts) ->
    this.$el = $('.merge-request')
    @diffs_loaded = @opts.action == 'diffs'
    @commits_loaded = false

    this.activateTab(@opts.action)

    this.bindEvents()

    this.initMergeWidget()
    this.$('.show-all-commits').on 'click', =>
      this.showAllCommits()

    $('#modal_merge_info').modal(show: false)

    disableButtonIfEmptyField '#merge_commit_message', '.accept_merge_request'

  # Local jQuery finder
  $: (selector) ->
    this.$el.find(selector)

  initMergeWidget: ->
    this.showState( @opts.current_status )

    if this.$('.automerge_widget').length and @opts.check_enable
      $.get @opts.url_to_automerge_check, (data) =>
        this.showState( data.merge_status )
      , 'json'

    if @opts.ci_enable
      $.get @opts.url_to_ci_check, (data) =>
        this.showCiState data.status
      , 'json'

  bindEvents: ->
    this.$('.nav-tabs').on 'click', 'a', (event) =>
      a = $(event.currentTarget)

      href = a.attr('href')
      History.replaceState {path: href}, document.title, href

      event.preventDefault()

    this.$('.nav-tabs').on 'click', 'li', (event) =>
      this.activateTab($(event.currentTarget).data('action'))

    this.$('.accept_merge_request').on 'click', ->
      $('.automerge_widget.can_be_merged').hide()
      $('.merge-in-progress').show()

  activateTab: (action) ->
    this.$('.nav-tabs li').removeClass 'active'
    this.$('.tab-content').hide()
    switch action
      when 'diffs'
        this.$('.nav-tabs .diffs-tab').addClass 'active'
        this.loadDiff() unless @diffs_loaded
        this.$('.diffs').show()
      else
        this.$('.nav-tabs .notes-tab').addClass 'active'
        this.$('.notes').show()

  showState: (state) ->
    $('.automerge_widget').hide().filter(".#{state}").show()

  showCiState: (state) ->
    $('.ci_widget').hide().filter("ci-#{state}").show()

  loadDiff: () ->
    $.ajax
      type: 'GET'
      url: this.$('.nav-tabs .diffs-tab a').attr('href')
      beforeSend: =>
        this.$('.status').addClass 'loading'
      complete: =>
        @diffs_loaded = true
        this.$('.status').removeClass 'loading'
      success: (data) =>
        this.$(".diffs").html(data.html)
      dataType: 'json'

  showAllCommits: ->
    this.$('.first-commits').remove()
    this.$('.all-commits').removeClass 'hide'

  alreadyOrCannotBeMerged: ->
    this.$('.automerge_widget, .merge-in-progress').hide()
    this.$('.automerge_widget.already_cannot_be_merged').show()

this.MergeRequest = MergeRequest
