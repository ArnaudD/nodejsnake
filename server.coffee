
http = require 'http'
io = require 'socket.io'

server = http.createServer (req, res) ->
 res.writeHead 200, {'Content-Type': 'text/html'}
 res.end '<h1>Hello from the websocket server !</h1>'

server.listen 8080

playersCount = 1; # TODO find something more elegant !


###############################################################################
#
# Model classes
#
###############################################################################

#------------------------------------------------------------------------------
# Grid model
#------------------------------------------------------------------------------
class Grid
  constructor: () ->
    @width  = 0
    @height = 0
    @map    = []

  clear: () ->
    @map = []

  init: (@width, @height) ->
    for x in [0...@width]
      @map[x] = []
      for y in [0...@height]
        @map[x][y] = null
    true

  isset: (x, y) ->
    (@map[x][y] == null)

  set: (x, y, player) ->
    @map[x][y] = player

  unset: (x, y) ->
    @map[x][y] = null

#------------------------------------------------------------------------------
# Game model
#------------------------------------------------------------------------------
class Game
  constructor: (@host) ->
    @players = []
    @speed   = 300
    @grid    = new Grid
    @loop    = null

    console.log 'Yeah, new game at '+@host

  addPlayer: (player) ->
    @players.push player
    
    #@broadcast ({addPlayer: {
    #  id: player.id,
    #  name: player.name
    #}})

    # Let's start immediately the game, TEMPORARY
    @getReady() if @players.length > 1 && @loop == null


  deletePlayer: (client) ->
    playerId = @players[client.sessionId].id
    
    if @players[client.sessionId]
      delete @players[client.sessionId]
    
    if @players.length == 0
      clearInterval (@loop)
    else
      @broadcast {deletePlayer: playerId}
    

  getReady: () ->
    # find the best best resolution
    width = 999999
    height = 999999
    for player in @players
      height = player.resolution.height if player.resolution.height < height
      width = player.resolution.width if player.resolution.width < width
    
    # TODO : check if the grid size isn't too small
    
    # Initialize the grid
    @grid.init width, height

    # Put everyone on the grid
    i = 1
    spaceBetweenSnakes = Math.floor (width / (@players.length + 1))
    for player in @players
      player.init i * spaceBetweenSnakes, Math.floor (height/ 2)
      i++
    
    # broadcast positions
    for player in @players
      @broadcast {addPlayer: {
        id: player.id
        name: player.name
        position: player.getHead()
      }}
    
    # Announce the game is about to start !
    @broadcast {getReady: {resolution: {width: width, height: height}}}
    
    # TODO set countdown !
    
    # TODO
    @start()
    

  countDown: () ->
    # TODO

  start: () ->
    # launch the main loop
    @loop = setInterval (() => @movePlayers()) , @speed
    
  movePlayers: () ->
    updates = []
    
    # Let's move the tail of each player first
    for player in @players
      move = player.moveTail (@grid)
      updates.push (move) if move
    
    # Then move their head
    for player in @players
      nextMove = player.getNextMoveCoordinate()
      if @grid.isset nextMove.x, nextMove.y
        updates.push (player.moveHead(nextMove))
    
    # Send direction to everyone in the game
    @broadcast update: updates
    

  broadcast: (message) ->
    for player in @players
      player.client.send message



#------------------------------------------------------------------------------
# Snake model
#------------------------------------------------------------------------------
class Snake
  constructor: (@game) ->
    @nodes     = []
    @direction = 'N'
    @size      = 10

  getHead: () ->
    @nodes[@nodes.length - 1]

  getNextMoveCoordinate: () ->
    x = @getHead().x
    y = @getHead().y
    switch (@direction)
      when 'S' then y++
      when 'N' then y--
      when 'E' then x++
      when 'W' then x--

    if x >= @game.grid.width
      x = 0
    if x < 0
      x = @game.grid.width - 1
    if y >= @game.grid.height
      y = 0
    if y < 0
      y = @game.grid.height - 1
    
    return {x: x, y: y}
    
  setDirection: (@direction) ->



#------------------------------------------------------------------------------
# Snake model
#------------------------------------------------------------------------------
class Player extends Snake
  constructor: (@client, @name, @resolution, game) ->
    @id         = playersCount++; # Client side ID
    console.log ('Yeah, new player "'+@name+'"')
    super game
    
  init: (x, y) ->
    @moveHead ({x: x, y: y})

  moveHead: (nextMove) ->
    @game.grid.set nextMove.x, nextMove.y, this
    @nodes.push nextMove
    {playerId: @id, action: 'addNode', pt: nextMove}

  moveTail: (grid) ->
    if @nodes.length == @size
      tail = @nodes.shift()
      grid.unset tail.x,tail.y
      {playerId: @id, action: 'cutTail'}
    

# 
# TODO Bot model !
# 


###############################################################################
#
# Controller class
#
###############################################################################

class Controller
  constructor: () ->
    @games   = {}
    @players = {}

  addPlayer: (client, params) ->
    domain = client.request.headers.origin
    if ! @games[domain]
      @games[domain] = new Game domain
    
    player = new Player client, params.name, params.resolution, @games[domain]
    
    @players[client.sessionId] = player
    @games[domain].addPlayer (player)
    

  setDirection: (client, direction) ->
    @players[client.sessionId].setDirection direction
    

  disconnect: (client) ->
    domain = client.request.headers.origin
    
    # Delete the player from the game
    @games[domain].deletePlayer client
    
    # Delete the player
    if @players[client.sessionId]
      delete @players[client.sessionId]
    
    # Delete the game if there is no more player
    if ! @games[domain].players.length == 0
      delete @games[domain]
    



###############################################################################
#
# Dispatcher
#
###############################################################################
socket = io.listen server
ctlr = new Controller
socket.on 'connection', (client) ->

  client.on 'message', (message) ->
    for command in Object.keys message
      console.log "New command "+command
      console.log message[command]
      if typeof ctlr[command] == 'function'
        ctlr[command] client, message[command]
      else
        console.log 'Command '+command+'does not exist.'
  
  client.on 'disconnect', () ->
    # FIXME ctlr.disconnect(client)


