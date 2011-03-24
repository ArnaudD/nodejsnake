
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
var Grid = function (width, height) {
  this.width  = width;
  this.height = height;
  this.map    = {};
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
  this.grid    = null;
  this.loop    = null;

  console.log ('Yeah, new game at '+this.host);
};

// TODO : create a broadcast method !

Game.prototype.addPlayer = function (player) {
  this.players.append (player);

  this.players.forEach(function (p) {
    p.client.send ({
      id: player.id,
      name: player.name
    });
  });

  // Let's start immediately the game, TEMPORARY
  this.start();
};

Game.prototype.deletePlayer = function (client) {
  if (this.players[client.sessionId]) {
    delete this.players[client.sessionId];
  }

  if (this.players.length == 0)
    clearInterval (this.loop);
};

Game.prototype.start = function () {
  // find the best best resolution
  var width = 999999, height = 999999;
  this.players.forEach(function (player) {
    if (player.resolution.height < height)
      width = player.resolution.height;
    if (player.resolution.width < width)
      width = player.resolution.width;
  });

  // TODO : check if the grid size isn't too small

  // Announce the game is about to start !
  this.players.forEach(function (player) {
    player.announceGame ({resolution: {width: width, height: height}});
  });

  // TODO set countdown !

  // Initialize the grid
  this.grid = new Grid (width, height);
  this.loop = setInterval (this.movePlayers(), this.speed);
};

Game.prototype.movePlayers = function () {
  this.players.forEach (function (player) {
    player.move();
    // TODO send direction of all players


    // TODO Update grid
  });
};

/**
 * Player model
 *
 *
 */
var Player = function (client, name, resolution) {
  this.id         = playersCount++;
  this.client     = client;
  this.name       = name;
  this.resolution = resolution;
  this.snake      = null;
  this.game       = null;

  console.log ('Yeah, new player "'+this.name+'"');
};

Player.prototype.setDirection = function (direction) {
  this.snake.direction = direction;
};

Player.prototype.move = function () {
  //this.snake.detectColision(); TODO

  this.client.send ({move: this.snake.direction});
};

Player.prototype.announceGame = function (settings) {
  this.client.send ({getReady: settings});
};

/**
 * Snake model
 *
 *
 */
var Snake = function (grid) {
  this.nodes     = {};
  this.grid      = grid;
  this.direction = 'N';

};

Snake.prototype.detectColision = function (client) {
};


/******************************************************************************
 *
 * Controller class
 *
 *****************************************************************************/
var Controller = function () {

  this.games   = {};
  this.players = {};

};

Controller.prototype.newPlayer = function (client, params) {
  var domain = client.request.headers.origin,
      player = new Player (client, params.name, params.resolution);

  this.players[client.sessionId] = player;

  if (! this.games[domain])
    this.games[domain] = new Game (domain);

  this.game.addPlayer (player);
};

Controller.prototype.setDirection = function (client, params) {
  this.players[client.sessionId].setDirection (params.direction);
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
var controller = new Controller ();
socket.on('connection', function(client){

  client.on('message', function(message){

    Object.keys(message).forEach(function (command) {
      console.log ("New command "+command);
      console.log (message[command]);
      if (Controller.prototype[command])
        Controller.prototype[command](client, message[command]);
      else
        console.log ('Command '+command+'does not exist.');
    });

    client.broadcast(direction);

  });
  client.on('disconnect', function(){
    Controller.disconnect(client);
  });
});