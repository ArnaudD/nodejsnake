
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
# Player container
#------------------------------------------------------------------------------
class PlayerContainer
  constructor: () ->
    @list = []
    @indexById = {}
    @indexBySessionId = {}

  add: (player) ->
    @list.push player
    @indexById[player.id] = @list.length - 1
    @indexBySessionId[player.client.sessionId] = @list.length - 1

  remove: (player) ->
      # TODO

  get: (id) ->
    if @list[@indexById[id]?]?
      @list[@indexById[id]]
    null

  getBySessionId: (sessionId) ->
    if @list[@indexBySessionId[sessionId]?]?
      @list[@indexBySessionId[sessionId]]
    null

  deleteBySessionId: (sessionId) ->
    @remove @getBySessionId sessionId

#------------------------------------------------------------------------------
# Game model
#------------------------------------------------------------------------------
class Game
  constructor: (@host) ->
    @players   = new PlayerContainer()
    @watchers  = new PlayerContainer()
    @speed     = 300
    @grid      = new Grid
    @loop      = null
    @countdown = 30 # countdown > 0 : waiting for players, countdown == 0 : playing
    console.log 'Yeah, new game at '+@host

  addWatcher: (player) ->
    console.log '> adding watcher '+player.name
    @watchers.add player

  addPlayer: (player) ->
    console.log '> adding player '+player.name
    @players.add player

    # debug: start at first player, next ones will be watching
    @start(); return

    if @players.players.length > 2 # the game can now begin
      @getReady()

  deletePlayer: (player) ->
    @players.remove player
    if @players.list.length == 0
    else
      @broadcast [{deletePlayer: playerId}]
    
  isStarted: () ->
    @countdown == 0

  countDown: () ->
    @broadcast [{getReady: @countDown}]
    @countDown--

    if @countDown < 0
      if @players.list.length < 2
        @countdown = 30 # restart countdown
      else
        @start()

  getReady: () ->
    # start countdown
    @loop = setInterval (() => @countdown()) , 1000
    
  start: () ->
    console.log '> starting game'
    # find the best best resolution
    width = 999999
    height = 999999
    for player in @players.list
      height = player.resolution.height if player.resolution.height < height
      width = player.resolution.width if player.resolution.width < width
    
    # TODO : check if the grid size isn't too small
    
    # Initialize the grid
    @grid.init width, height

    console.log 3
    # Put everyone on the grid
    i = 1
    spaceBetweenSnakes = Math.floor (width / (@players.list.length + 1))
    for player in @players.list
      player.init i * spaceBetweenSnakes, Math.floor (height/ 2)
      i++
    
    console.log 4
    # broadcast positions
    playersPosition = []
    for player in @players.list
      playersPosition.push addPlayer: {
        id: player.id
        name: player.name
        position: player.getHead()
      }

    @broadcast playersPosition

    # Announce the game is starting
    @broadcast [{start: {resolution: {width: width, height: height}}}]
    
    @loop = setInterval (() => @movePlayers()) , @speed

  stop: () ->
    clearInterval (@loop)
    # TODO announce 

  movePlayers: () ->
    updates = []
    
    # Let's move the tail of each player first
    for player in @players.list
      if player.moveTail (@grid)
        updates.push cutTail: player.id
    
    # Then move their head
    for player in @players.list
      nextMove = player.getNextMoveCoordinate()
      if @grid.isset nextMove.x, nextMove.y
        player.moveHead nextMove
        updates.push addNode: {playerId: player.id, x: nextMove.x, y: nextMove.y}
    
    # Send direction to everyone in the game
    @broadcast updates
    

  broadcast: (message) ->
    for player in @players.list
      player.send message
    for watcher in @watchers.list
      watcher.send message
    @



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
    switch @direction
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
# Player model
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
    true # FIXM

  moveTail: (grid) ->
    if @nodes.length == @size
      tail = @nodes.shift()
      grid.unset tail.x, tail.y
      true
    else
      false
    
  send: (message) ->
    @client.send message

#------------------------------------------------------------------------------
# Bot model
#------------------------------------------------------------------------------ 
class BotPlayer extends Snake
  constructor: (@game) ->
    # TODO


###############################################################################
#
# Controller class
#
###############################################################################

class Controller
  constructor: (@socket) ->
    @games   = {}
    socket.on 'connection', (client) => @handleConnection (client)

  # server events >

  handleConnection: (client) ->
    client.on 'message',    (message) => @handleMessage       client, message
    client.on 'disconnect', (client)  => @handleDisconnection client

  handleDisconnection: (client) ->
    domain = client.request.headers.origin
    
    # Delete the player from the game
    @games[domain].players.deleteBySessionId client.sessionId
    @games[domain].watchers.deleteBySessionId client.sessionId
    
    # Delete the game if there is no more player
    if @games[domain].players.length == 0 && @games[domain].watchers.length == 0
      delete @games[domain]

  handleMessage: (client, message) ->
    for command in Object.keys message
      console.log "New command "+command
      console.log message[command]
      if @[command]?(client, message[command]) == undefined # if method 'command' exist, call it
        console.log '[ERROR] Command '+command+' does not exist.'
    true


  # tools >

  getGameForClient: (client) ->
    domain = client.request.headers.origin
    # create a game if there is none
    if ! @games[domain]
      @games[domain] = new Game domain
    

  # player commands >

  addPlayer: (client, params) ->
    game = @getGameForClient client

    player = new Player client, params.name, params.resolution, game
    if game.isStarted()
      game.addWatcher player
    else
      game.addPlayer player

  setDirection: (client, direction) ->
    @game.players.getBySessionId (client.setDirection)?.setDirection direction



###############################################################################
#
# Dispatcher
#
###############################################################################
socket = io.listen server
ctlr = new Controller socket


