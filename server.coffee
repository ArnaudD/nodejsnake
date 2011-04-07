
path     = require 'path'
http     = require 'http'
io       = require 'socket.io'
paperboy = require 'paperboy'

WEBROOT  = path.join(path.dirname(__filename), 'public')
PORT     = 80

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
    (@map[x][y] != null)

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

  add: (player) ->
    @list.push player
    @indexById[player.id] = @list.length - 1

  remove: (player) ->
    idx = @indexById[player.id]
    @list.splice idx, 1
    delete @indexById[player.id]

  get: (id) ->
    if @list[@indexById[id]?]?
      @list[@indexById[id]]
    else
      null


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
    @countdownLoop = null
    console.log 'Yeah, new game at '+@host

  #
  # Adds a watcher to the game
  #
  addWatcher: (player) ->
    console.log '> adding watcher '+player.name
    @watchers.add player
    # send him players details
    player.send @getPlayersData()

  #
  # Adds a player to the game
  #
  addPlayer: (player) ->
    console.log '> adding player '+player.name
    @players.add player

    # debug: start at first player, next ones will be watching
    @start(); return

    if @players.list.length > 2 # the game can now begin
      @getReady()

  #
  # Called when someone is disconnected
  #
  deletePlayer: (player) ->
    @broadcast kill: player.id
    @players.remove player

  #
  # Called when someone is killed
  # Put the player in the watchers list
  #
  killPlayer: (player) ->
    @watchers.add player
    @deletePlayer player

    if @players.list.length == 0
      @stop()
      @getReady() # ... for the next round
    
  #
  # Tells if the game has already started
  #
  isStarted: () ->
    @loop != null

  #
  # Method called every second before the begining of the countdown
  #
  getReady: () ->
    if @countdownLoop == null
      # init the countdown
      @countdown = 2 # FIXME debug # restart countdown
      @countdownLoop = setInterval (() => @getReady()) , 1000
      @players = @watchers
      @watchers = new PlayerContainer()

    console.log '> the game is starting in '+@countdown+'s'
    @broadcast getReady: @countdown
    @countdown--

    if @countdown < 0
      if @players.list.length < 1 # FIXME DEBUG
        @countdown = 30 # restart countdown
      else
        clearInterval @countdownLoop
        @countdownLoop = null
        @start()
    
  #
  # Start a game
  # Called at the end of the countdown to initialize the grid size, 
  # and the players positions, and start the main loop
  #
  start: () ->
    console.log '> starting game, number of players : '+@players.list.length
    # find the best best resolution
    width = 999999
    height = 999999
    for player in @players.list
      height = player.resolution.height if player.resolution.height < height
      width = player.resolution.width if player.resolution.width < width
    
    # TODO : check if the grid size isn't too small
    
    # Initialize the grid
    @grid.clear()
    @grid.init width, height

    # Put everyone on the grid
    i = 1
    spaceBetweenSnakes = Math.floor (width / (@players.list.length + 1))
    for player in @players.list
      player.isAlive = true # just to make sure
      player.init i * spaceBetweenSnakes, Math.floor (height/ 2)
      i++
    
    # broadcast players infos
    @broadcast @getPlayersData()

    # Announce the game is starting
    @broadcast start: {resolution: {width: width, height: height}}
    
    @loop = setInterval (() => @movePlayers()) , @speed

  #
  # Game main loop
  #
  movePlayers: () ->
    updates = []
    i = @players.list.length
    while i--
      player = @players.list[i]
      player.move @grid
      if ! player.isAlive
        @killPlayer player
      else
        updates.push move: {playerId: player.id, x: player.getHead().x, y: player.getHead().y}
    
    # Send direction to everyone in the game
    @broadcast updates
    
  #
  # Called at the end of the game to stop the main loop
  #
  stop: () ->
    @broadcast stop: 0
    clearInterval (@loop)
    # TODO announce 

  #
  # Returns players metadata (id, name, position, site, etc)
  #
  getPlayersData: () ->
    data = []
    for player in @players.list
      data.push addPlayer: {
        id: player.id
        name: player.name
        position: player.getHead()
        size: player.size
      }
    data

  #
  # Utility function to send a message to every player (and watcher) of this game
  #
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
    @isAlive   = true

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
    
  setDirection: (direction) ->
    @direction = direction if (
      (direction == 'N' && @direction != 'S') ||
      (direction == 'S' && @direction != 'N') ||
      (direction == 'E' && @direction != 'W') ||
      (direction == 'W' && @direction != 'E')
    )

  init: (x, y) ->
    @moveHead ({x: x, y: y})

  move: (grid) ->
    @grow
    nextMove = @getNextMoveCoordinate()
    if ! grid.isset nextMove.x, nextMove.y
      @moveHead nextMove
      @moveTail grid
    else
      @isAlive = false

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

  grow: () ->
    # TODO


#------------------------------------------------------------------------------
# Player model
#------------------------------------------------------------------------------
class Player extends Snake
  constructor: (@client, @name, @resolution, game) ->
    @id         = playersCount++; # Client side ID
    console.log 'Yeah, new player "'+@name+'"'
    super game
       
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
    @players = {}
    socket.on 'connection', (client) => @handleConnection (client)

  # server events >

  handleConnection: (client) ->
    client.on 'message',    (message) => @handleMessage       client, message
    # client.on 'disconnect', (client)  => @handleDisconnection client

  handleDisconnection: (client) ->
    domain = client.request.headers.origin
    @removePlayer client
    if @games[domain].players.length == 0 && @games[domain].watchers.length == 0
      delete @games[domain]

  handleMessage: (client, message) ->
    for command in Object.keys message
      console.log "New command "+command
      console.log message[command]
      if typeof @[command] == 'function'
        @[command](client, message[command])
      else
        console.log '[ERROR] Command '+command+' does not exist.'
    true


  # tools >

  getGameForClient: (client) ->
    domain = client.request.headers.origin
    # create a game if there is none
    if ! @games[domain]
      @games[domain] = new Game domain
    @games[domain]
    
  getPlayer: (client) ->
    if @players[client.sessionId]?
      @players[client.sessionId]
    else
      null

  deletePlayer: (client) ->
    player = @getPlayer client
    game = @getGameForClient client
    game.deletePlayer player
    delete @players[client.sessionId]

    if @game.players.list.length == 0
      @deleteGame game

  deleteGame: (game) ->
    delete @games[game.host]

  # player commands >

  addPlayer: (client, params) ->
    game   = @getGameForClient client
    player = new Player client, params.name, params.resolution, game
    @players[client.sessionId] = player
    if game.isStarted()
      game.addWatcher player
    else
      game.addPlayer player

  setDirection: (client, direction) ->
    (@getPlayer client)?.setDirection direction



###############################################################################
#
# Dispatcher
#
###############################################################################


server = http.createServer (req, res) ->
  d = paperboy.deliver WEBROOT, req, res
  d.before () ->
      console.log 'Received Request'
  d.error (statCode, msg) ->
      res.writeHead statCode, {'Content-Type': 'text/plain'}
      res.end "Error " + statCode
  d.otherwise (err) ->
      res.writeHead 404, {'Content-Type': 'text/plain'}
      res.end "Error 404: File not found"

server.listen PORT
socket = io.listen server

ctlr = new Controller socket


