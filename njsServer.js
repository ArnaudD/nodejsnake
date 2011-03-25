
var http = require('http'),
    io = require('socket.io'),

server = http.createServer(function(req, res){
 res.writeHead(200, {'Content-Type': 'text/html'});
 res.end('<h1>Hello from the websocket server !</h1>');
});
server.listen(8080);

var playersCount = 1; // TODO find something more elegant !


/******************************************************************************
 *
 * Model classes
 *
 *****************************************************************************/

/**
 * Grid model
 *
 *
 */
var Grid = function () {
  this.width  = 0;
  this.height = 0;
  this.map    = [];
};

Grid.prototype.init = function (width, height) {
  this.width  = width;
  this.height = height;

  for (var x=0; x<this.width; x++){
    this.map [x] = [];
    for (var y=0; y<this.height; y++)
      this.map [x][y] = null;
  }
};

Grid.prototype.isFree = function (x, y) {
  return (this.map[x][y] == null);
};

Grid.prototype.set = function (x, y, player) {
  this.map[x][y] = player;
};

Grid.prototype.unset = function (x, y) {
  this.map[x][y] = null;
};

/**
 * Game model
 *
 *
 */
var Game = function (host) {
  this.host    = host;
  this.players = [];
  this.speed   = 200;
  this.grid    = new Grid ();
  this.loop    = null;

  console.log ('Yeah, new game at '+this.host);
};

Game.prototype.addPlayer = function (player) {
  this.players.push (player);

  this.broadcast ({addPlayer: {
    id: player.id,
    name: player.name
  }});

  // Let's start immediately the game, TEMPORARY
  this.start();
};

Game.prototype.deletePlayer = function (client) {
  var playerId = this.players[client.sessionId].id;

  if (this.players[client.sessionId]) {
    delete this.players[client.sessionId];
  }

  if (this.players.length == 0)
    clearInterval (this.loop);
  else
    this.broadcast({deletePlayer: playerId});
};

Game.prototype.start = function () {
  // find the best best resolution
  var width = 999999, height = 999999;
  this.players.forEach(function (player) {
    if (player.resolution.height < height)
      height = player.resolution.height;
    if (player.resolution.width < width)
      width = player.resolution.width;
  });

  // TODO : check if the grid size isn't too small

  // Initialize the grid
  this.grid.init (width, height);

  // Put everyone on the grid
  var i = 1;
  var spaceBetweenSnakes = Math.floor(width / (this.players.length + 1));
  this.players.forEach(function (player) {
    player.init (i * spaceBetweenSnakes, Math.floor(height/ 2));
    i++;
  });
  // TODO : broadcast positions

  // Announce the game is about to start !
  this.broadcast({getReady: {resolution: {width: width, height: height}}});

  // TODO set countdown !

  // launch the main loop
  var self = this;
  this.loop = setInterval (function () {self.movePlayers();}, this.speed);
};

Game.prototype.movePlayers = function () {
  var updates = [];
  var self = this;

  // Let's move the tail of each player first
  this.players.forEach (function (player) {
    var move = player.moveTail (self.grid);
    if (move)
      updates.push (move);
  });

  // Then move their head
  this.players.forEach (function (player) {
    var nextMove = player.getNextMoveCoordinate ();
    if (self.grid.isFree (nextMove.x, nextMove.y))
      updates.push (player.moveHead(nextMove));
  });

  // Send direction to everyone in the game
  this.broadcast ({update: updates});
};

Game.prototype.broadcast = function (message) {
  this.players.forEach (function (player) {
    player.client.send (message);
  });
};


/**
 * Snake model
 *
 *
 */
var Snake = function (game) {
  this.nodes     = [];
  this.direction = 'N';
  this.size      = 10;
  this.game      = game;

};

Snake.prototype.getNextMoveCoordinate = function () {
  var x = this.nodes[this.nodes.length - 1].x ;
  var y = this.nodes[this.nodes.length - 1].y ;
  switch (this.direction) {
    case 'S': y++; break;
    case 'N': y--; break;
    case 'E': x++; break;
    case 'W': x--; break;
  }

  if (x >= this.game.grid.width)  x = 0;
  if (x < 0)                      x = this.game.grid.width - 1;
  if (y >= this.game.grid.height) y = 0;
  if (y < 0)                      y = this.game.grid.height - 1;

  return {x: x, y: y};
};

Snake.prototype.setDirection = function (direction) {
  this.direction = direction;
};

Snake.prototype.init = function (x, y) {
  this.nodes.push ({x: x, y: y});
};

/**
 * Player model
 *
 *
 */
var Player = function (client, name, resolution, game) {
  this.id         = playersCount++; // Client side ID
  this.client     = client;
  this.name       = name;
  this.resolution = resolution;
  this.game       = game;

  console.log ('Yeah, new player "'+this.name+'"');
};

Player.prototype = new Snake (null); // A player is a snake

Player.prototype.moveHead = function (nextMove) {
  this.game.grid.set (nextMove.x, nextMove.y, this);
  this.nodes.push (nextMove);
  return {playerId: this.id, action: 'addNode', pt: nextMove};
};

Player.prototype.moveTail = function (grid) {
  if (this.nodes.length == this.size) {
    var tail = this.nodes.shift();
    grid.unset (tail.x,tail.y);
    return {playerId: this.id, action: 'cutTail'};
  }
};

/**
 * TODO Bot model !
 */

/******************************************************************************
 *
 * Controller class
 *
 *****************************************************************************/
var Controller = function () {

  this.games   = {};
  this.players = {};

};

Controller.prototype.addPlayer = function (client, params) {
  var domain = client.request.headers.origin;
  if (! this.games[domain])
    this.games[domain] = new Game (domain);

  var player = new Player (client, params.name, params.resolution, this.games[domain]);

  this.players[client.sessionId] = player;
  this.games[domain].addPlayer (player);
};

Controller.prototype.setDirection = function (client, direction) {
  this.players[client.sessionId].setDirection (direction);
};

Controller.prototype.disconnect = function (client) {
  var domain = client.request.headers.origin;

  // Delete the player from the game
  this.games[domain].deletePlayer(client);

  // Delete the player
  if (this.players[client.sessionId]) {
    delete this.players[client.sessionId];
  }

  // Delete the game if there is no more player
  if (! this.games[domain].players.length == 0)
    delete this.games[domain];
};



/******************************************************************************
 *
 * Dispatcher
 *
 *****************************************************************************/
var socket = io.listen(server);
socket.on('connection', function(client){
  var ctlr = new Controller ();

  client.on('message', function(message){

    Object.keys(message).forEach(function (command) {
      console.log ("New command "+command);
      console.log (message[command]);
      if (typeof ctlr[command] == 'function')
        ctlr[command](client, message[command]);
      else
        console.log ('Command '+command+'does not exist.');
    });

  });
  client.on('disconnect', function(){
    // FIXME ctlr.disconnect(client);
  });
});