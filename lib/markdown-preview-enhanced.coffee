MarkdownPreviewEnhancedView = require './markdown-preview-enhanced-view'
{CompositeDisposable} = require 'atom'
path = require 'path'
insertImageView = require './image-helper-view'


{getReplacedTextEditorStyles} = require './style'

module.exports = MarkdownPreviewEnhanced =
  preview: null,
  katexStyle: null,

  activate: (state) ->
    # console.log 'actvate markdown-preview-enhanced', state
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # set opener
    atom.workspace.addOpener (uri)=>
      if (uri.startsWith('markdown-preview-enhanced://'))
        return @preview

    @preview = new MarkdownPreviewEnhancedView(state, 'markdown-preview-enhanced://preview')

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace',
      'markdown-preview-enhanced:toggle': => @toggle()
      'markdown-preview-enhanced:customize-css': => @customizeCSS()
      'markdown-preview-enhanced:toc-create': => @createTOC()
      'markdown-preview-enhanced:toggleScrollSync': => @toggleScrollSync()
      'markdown-preview-enhanced:insert-table': => @insertTable()
      'markdown-preview-enhanced:image-helper': => @startImageHelper()


    # when the preview is displayed
    # preview will display the content of pane that is activated
    atom.workspace.onDidChangeActivePaneItem (editor)=>
    	if editor and
        	editor.buffer and
        	editor.getGrammar and
        	editor.getGrammar().scopeName == 'source.gfm' and
        	@preview and
        	@preview.isOnDom()
        if @preview.editor != editor
          @preview.bindEditor(editor)

    # automatically open preview when activate a markdown file
    # if 'openPreviewPaneAutomatically' option is enable
    atom.workspace.onDidOpen (event)=>
      if atom.config.get('markdown-preview-enhanced.openPreviewPaneAutomatically')
        if event.uri and
            event.item and
            event.uri.endsWith('.md')
          pane = event.pane
          panes = atom.workspace.getPanes()

          # if the markdown file is opened on the right pane, then move it to the left pane. Issue #25
          if pane != panes[0]
            pane.moveItemToPane(event.item, panes[0], 0) # move md to left pane.
            panes[0].setActiveItem(event.item)

          editor = event.item
          @startMDPreview(editor)

  deactivate: ->
    @subscriptions.dispose()
    @preview.destroy()

    # console.log 'deactivate markdown-preview-enhanced'

  serialize: ->
    # console.log 'package serialize'
    state: @preview.serialize()

  toggle: ->
    if @preview.isOnDom()
      @preview.destroy()
    else
      ## check if it is valid markdown file
      editor = atom.workspace.getActiveTextEditor()
      @startMDPreview(editor)

  startMDPreview: (editor)->
    if @preview.editor == editor
      return true
    else if @checkValidMarkdownFile(editor)
      @appendGlobalStyle()
      @preview.bindEditor editor
      return true
    else
      return false

  checkValidMarkdownFile: (editor)->
    if !editor or !editor.getFileName()
      atom.notifications.addError('Markdown file should be saved first.')
      return false

    fileName = editor.getFileName().trim()
    if !fileName.endsWith('.md')
      atom.notifications.addError('Invalid Markdown file: ' + fileName + '. The file extension should be .md' )
      return false

    buffer = editor.buffer
    if !buffer
      atom.notifications.addError('Invalid Markdown file: ' + fileName)
      return false

    return true

  appendGlobalStyle: ()->
    if not @katexStyle
      @katexStyle = document.createElement 'link'
      @katexStyle.rel = 'stylesheet'
      @katexStyle.href = path.resolve(__dirname, '../node_modules/katex/dist/katex.min.css')
      document.getElementsByTagName('head')[0].appendChild(@katexStyle)

      textEditorStyle = document.createElement('style')
      textEditorStyle.innerHTML = getReplacedTextEditorStyles()
      textEditorStyle.setAttribute('for', 'markdown-preview-enhanced')

      head = document.getElementsByTagName('head')[0]
      atomStyles = document.getElementsByTagName('atom-styles')[0]
      head.insertBefore(textEditorStyle, atomStyles)

  customizeCSS: ()->
    atom.workspace
      .open("atom://.atom/stylesheet")
      .then (editor)->
        customCssTemplate = """\n
/*
 * markdown-preview-enhanced custom style
 */
.markdown-preview-enhanced-custom {
  // please write your custom style here
  // eg:
  //  color: blue;          // change font color
  //  font-size: 14px;      // change font size
  //

  // custom pdf output style
  @media print {

  }
}

// please don't modify the .markdown-preview-enhanced section below
.markdown-preview-enhanced {
  .markdown-preview-enhanced-custom() !important;
}
"""
        text = editor.getText()
        if text.indexOf('.markdown-preview-enhanced-custom {') < 0 or         text.indexOf('.markdown-preview-enhanced {') < 0
          editor.setText(text + customCssTemplate)

  # insert toc table
  # if markdown preview is not opened, then open the preview
  createTOC: ()->
    editor = atom.workspace.getActiveTextEditor()

    if editor and @startMDPreview(editor)
      editor.insertText('\n<!-- toc orderedList:0 -->\n')

  toggleScrollSync: ()->
    flag = atom.config.get 'markdown-preview-enhanced.scrollSync'
    atom.config.set('markdown-preview-enhanced.scrollSync', !flag)

    if !flag
      atom.notifications.addInfo('Scroll Sync enabled')
    else
      atom.notifications.addInfo('Scroll Sync disabled')

  insertTable: ()->
    addSpace = (num)->
      output = ''
      for i in [0...num]
        output += ' '
      return output

    editor = atom.workspace.getActiveTextEditor()
    if editor and editor.buffer
      cursorPos = editor.getCursorBufferPosition()
      editor.insertText """|  |  |
  #{addSpace(cursorPos.column)}|--|--|
  #{addSpace(cursorPos.column)}|  |  |
  """
      editor.setCursorBufferPosition([cursorPos.row, cursorPos.column + 2])
    else
      atom.notifications.addError('Failed to insert table')

  # start image helper
  startImageHelper: ()->
    editor = atom.workspace.getActiveTextEditor()
    if editor and editor.buffer
      insertImageView.display(editor)
    else
      atom.notifications.addError('Failed to open Image Helper panel')