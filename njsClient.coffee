
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
    @nodes.shift()


#------------------------------------------------------------------------------
# Canvas Model
#------------------------------------------------------------------------------

class SnakeCanvas
  constructor: () ->
    @raphael = Raphael 0, 0, document.width, document.height
    @raphael.canvas.id = 'njsGrid'
    @nodeSize = 10
    @resolution = # grid resolution
      height: Math.floor document.height / (@nodeSize + 1)
      width:  Math.floor document.width / (@nodeSize + 1)

    # TODO : adjust node size to meet the minimum resolution

  addNode: (x, y, color) ->
    # TODO center the grid
    x = (x * (@nodeSize+1)) + 1
    y = (y * (@nodeSize+1)) + 1
    node = @raphael.rect x, y, @nodeSize, @nodeSize
    node.attr fill: color, stroke: 'none'
    node.animate {fill: '#FFF'}, 4000

  removeNode: (node) ->
    node.animate {opacity: 0}, 200, () ->
      @remove()


#------------------------------------------------------------------------------
# Canvas Model
#------------------------------------------------------------------------------

class GameConsole
  constructor: (@container) ->

  log: (message) ->
    @container.append '<li>'+message+'</li>'

###############################################################################
#
# Controller class
#
###############################################################################

class Controller
  constructor: (@socket) ->
    @players = {}
    @canvas = new SnakeCanvas
    @gridSize = {}
    @direction = 'N'

    # Init keypress handler
    $('body').keydown (e) => @handleKeyPressed e

    # Server message handler
    socket.on 'message', (message) => @handleMessageReceived message
    socket.on 'connect',        () => @handleConnectionSucceed()
    socket.on 'connect_failed', () => @handleConnectionFailed()

  # event handlers >

  handleConnectionFailed: () ->
    alert 'Error connecting to the game server.'

  handleConnectionSucceed: () ->
    # Notify server of the new player
    name = 'AAA' # debug... prompt 'What\'s your name ?'
    @socket.send addPlayer: {name: name, resolution: @canvas.resolution}

  handleMessageReceived: (message) ->
    for command in Object.keys message
      console.log '> Command '+command+' received'
      if @[command]?(message[command]) == undefined # if method 'command' exist, call it
        console.log '[ERROR] Command "'+command+'" doesn\'t exist.'
    true

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

  getReady: ()

  addPlayer: (player) ->
    @players[player.id] = new Snake player.id, player.name

  start: (params) ->
    @gridSize = params.resolution

  addNode: (node) ->
    color = '#0F0' # TODO
    square = @canvas.addNode node.x, node.y, color
    @players[node.playerId].addHead square

  cutTail: (playerId) ->
    @canvas.removeNode @players[playerId].cutTail()

###############################################################################
#
# Controller classes
#
###############################################################################

socket = new io.Socket 'code.didry.info', {port: 8080, rememberTransport: false}
game = new Controller socket
socket.connect()

