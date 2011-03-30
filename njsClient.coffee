
nodeSize   = 10 # Size (in px) of one snake node

###############################################################################
#
# Model classes
#
###############################################################################

#------------------------------------------------------------------------------
# Snake model
#------------------------------------------------------------------------------

class Snake
  constructor: (id, name) ->
    @nodes = [] # Raphael nodes
    @color = '#0F0'

  addHead: (node) ->
    @nodes.push node

  cutTail: () ->
    deletedNode = @nodes.shift()
    deletedNode.animate {opacity: 0}, 200, () ->
      @remove()

#------------------------------------------------------------------------------
# Canvas Model
#------------------------------------------------------------------------------

class SnakeCanvas extends Raphael
  constructor: () ->
    super 0, 0, document.width, document.height
    @canvas.id = 'njsGrid'

  addNode: (x, y, color) ->
    # TODO center the grid
    x = (x * (nodeSize+1)) + 1
    y = (y * (nodeSize+1)) + 1
    node = @rect x, y, nodeSize, nodeSize
    node.attr fill: color, stroke: 'none'
    node.animate fill: '#FFF', 1000

###############################################################################
#
# Controller class
#
###############################################################################

class Controller
  constructor: (@socket) ->
    @players = {}
    @name = prompt 'What\'s your name ?'
    @resolution =
      height: Math.floor document.height / (nodeSize + 1)
      width:  Math.floor document.width / (nodeSize + 1)
    @canvas = new SnakeCanvas
    @gridSize = {}
    @players = {}

    @direction = 'N'

    # Init keypress handler
    ($ 'body').keydown (e) => @handleKeyPressed e

    # Server message handler
    socket.on 'message', (message) => @handleMessageReceived message
    socket.on 'connect_failed', () => @handleConnectionFailed

  # event handlers >

  handleConnectionFailed: () ->
    alert 'Error connecting to the game server.'

  handleConnectionSucceed: () ->
    # Notify server of the new player
    @socket.send addPlayer: {name: @name, resolution: @resolution}

  handleMessageReceived: (message) ->
    for command, params in message
      if @[command]?() # if method 'command' exist
        #console.log ("New command "+command)
        #console.log (params)
        @[command](params)
      else
        console.log 'Command '+command+' does not exist.'

  handleKeyPressed: (e) ->
    direction = null
    switch e.which
      when 37 then direction = 'W'
      when 38 then direction = 'N'
      when 39 then direction = 'E'
      when 40 then direction = 'S'
      
    if direction != null # TODO check if direction has already been sent
      @socket.send setDirection: direction
      e.preventDefault()

  # Server commands >

  addPlayer: (player) ->
    @players[player.id] = new Snake player.id, player.name, @canvas

  getReady: (params) ->
    @gridSize = params.resolution

  addNode: (node) ->
    color = '#0F0' # TODO
    square = @canvas.addNode node.x, node.y, color
    @players[node.playerId].addHead square

  cutTail: (playerId) ->
        @players[playerId].cutTail()

###############################################################################
#
# Controller classes
#
###############################################################################

socket = new io.Socket 'code.didry.info', {port: 8080, rememberTransport: false}
new Controller socket
socket.connect()

