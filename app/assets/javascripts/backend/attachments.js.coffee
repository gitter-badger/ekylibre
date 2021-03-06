(($) ->

  "use strict"

  $.widget "ui.attachmentController",
    options:
      fullWidget: false
      fullWidgetClass: 'expanded'

    _create: ->
      $.extend(true, @options, @element.data("attachment-controller"))

      widget = @
      @$el = $(@.element)
      @root = @.element.closest('.attachments')

      @$el.fileupload
        dataType: 'json',
        dropZone: '.attachment-files'
        add: (e, data) =>
          $el = $('<div class="file">\
            <div class="file-body">\
            <div class="file-actions">\
            <a href="" data-attachment-destroy="true" disabled><i></i></a>\
            </div>\
            <div class="file-name">'+data.files[0].name+'<div>\
            </div>\
            </div>')

          data.context = $el.appendTo(@root.find('.attachment-files'))

          @refreshPlaceholder()

          # send request
          data.submit()
          true

        submit: (e, data) ->
          data.formData =
            'attachments[document_attributes][name]': data.files[0].name
            'attachments[document_attributes][key]': "#{new Date().getTime()}-#{data.files[0].name}"
            'attachments[document_attributes][uploaded]': true

          file = data.context.closest('.file')
          file.addClass 'loading'
          true

        progressall: (e, data) ->
          $('.attachment-files-bitrate').text((data.bitrate / 1024).toFixed(2) + 'Kb/s')

        done: (e, data) ->
          file = $(data.context).closest('.file')
          result = data.result
          file.attr('data-attachment-thumblink', result.attachment_path)
          file.find('.file-name').html(result.attachment.name)
          file.removeClass('loading').removeClass('failed')

          file.find('.file-body').css("background-image", "url('#{result.thumb}')")

          indicator = file.find('*[data-attachment-destroy]')
          indicator.data('href', result.attachment_path)
          indicator.removeAttr 'disabled'

        fail: (e, data) ->
          file = $(data.context).closest('.file')
          file.removeClass('loading').addClass('failed')
          indicator = file.find('*[data-attachment-destroy]')
          indicator.attr('title', data.errorThrown)

        always: () ->
          $('.attachment-files-bitrate').text('')

      $(document).on 'click', '*[data-attachment-destroy]', (e) ->
        e.preventDefault()
        url = $(this).attr('href')
        if url
          $.ajax
            url: url
            method: 'post'
            data: {"_method": "delete"}
            success: (data) =>
              $(e.currentTarget).closest('.file').remove()
              widget.refreshPlaceholder()
            error: (data) =>
              $(e.currentTarget).closest('.file').addClass 'failed'
              console.log 'Unable to delete file'
        else
          $(e.currentTarget).closest('.file').remove()
          widget.refreshPlaceholder()

        false

      $(document).on 'click', '*[data-attachment-thumblink] .file-name, *[data-attachment-thumblink] .file-body', (e) ->
        e.preventDefault()
        url = $(this).closest('*[data-attachment-thumblink]').data('attachment-thumblink')
        $.ajax
          url: url
          method: 'GET'
          success: (data) ->
            $el = $("<iframe src='#{data.url}'/>")
            $modal = $('*[data-attachment-thumblink-target]')
            $modal.find('.modal-title').html(data.name)
            $modal.find('.modal-body').html($el)
            $modal.modal('show')
          error: (data) ->
            console.log 'Unable to load file'

        false

      $(document).on 'click','*[data-attachments-expand]', (e) ->
        e.preventDefault()
        widget.toggleWidget()

      $(document).bind 'dragover', (e) ->
        dropZone = $('.attachment-files')
        timeout = window.dropZoneTimeout
        if !timeout
          dropZone.addClass 'in'
        else
          clearTimeout timeout
        found = false
        node = e.target
        loop
          if node == dropZone[0]
            found = true
            break
          node = node.parentNode
          unless node != null
            break
        if found
          dropZone.addClass 'hover'
        else
          dropZone.removeClass 'hover'
        window.dropZoneTimeout = setTimeout((->
          window.dropZoneTimeout = null
          dropZone.removeClass 'in hover'
          return
        ), 100)
        return

      @refreshPlaceholder()

    refreshPlaceholder: ->

      if @root.find('.attachment-files').find('.file').length > 0
        @root.find('.attachment-files-placeholder').hide()
        @root.find('*[data-attachments-expand]').show()
      else
        @root.find('.attachment-files-placeholder').show()
        @root.find('*[data-attachments-expand]').hide()


    toggleWidget: ->
      @options.fullWidget = !@options.fullWidget
      if @options.fullWidget
        $('.attachments').addClass @options.fullWidgetClass
      else
        $('.attachments').removeClass @options.fullWidgetClass

  $(document).ready ->
    $("*[data-attachment]").each ->
      $(@).attachmentController()

) jQuery
