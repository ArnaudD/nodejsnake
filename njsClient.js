
(function() {

var nodeSize   = 10; // Size (in px) of one snake node

/******************************************************************************
 *
 * Model classes
 *
 *****************************************************************************/

  /**
   * Snake class
   * @param paper
   */
  var Snake = function (id, name, paper) {
    this.id    = id;
    this.name  = name;
    this.nodes = []; // Raphael nodes
    this.paper = paper;
    this.color = '#0F0';
  };

  Snake.prototype.addNode = function (x,y) {
    // TODO center the grid

    var rect = this.paper.rect((x * (nodeSize+1)) + 1, (y * (nodeSize+1)) + 1, nodeSize, nodeSize).attr({
      fill: this.color,
      stroke: 'none'
    }).animate ({fill: '#FFF'}, 200 * this.size);
    this.nodes.push (rect);
  };

  Snake.prototype.cutTail = function () {
    var deletedNode = this.nodes.shift();
    deletedNode.animate({opacity: 0}, 200, function () {
      this.remove();
    });
  };


  /******************************************************************************
   *
   * Controller class
   *
   *****************************************************************************/

  var Controller = function (socket) {

    this.socket = socket;
    this.players = {};
    this.name = prompt('What\'s your name ?');
    this.resolution = {
      height: Math.floor (document.height / (nodeSize + 1)),
      width:  Math.floor (document.width / (nodeSize + 1))
    };
    this.gridSize = {};
    this.players = {};
    this.paper = Raphael(0, 0, document.width, document.height);
    this.paper.canvas.id = 'njsGrid';
    this.direction = 'N';

    socket.send({
      addPlayer: {name: this.name, resolution: this.resolution}
    });

    $('body').keydown (function (e) {
      var direction = null;
      switch (e.which) {
        case 37: direction = 'W'; break;
        case 38: direction = 'N'; break;
        case 39: direction = 'E'; break;
        case 40: direction = 'S'; break;
      }
      if (direction != null) // TODO check if direction has already been sent
        socket.send({setDirection: direction});
    });

    var self = this;
    socket.on('message', function(message){
      Object.keys(message).forEach(function (command) {
        console.log ("New command "+command);
        console.log (message[command]);
        if (typeof self[command] == 'function')
          self[command](message[command]);
        else
          console.log ('Command '+command+' does not exist.');
      });
    });

  };

  Controller.prototype.addPlayer = function (player) {
    this.players[player.id] = new Snake (player.id, player.name, this.paper);
  };

  Controller.prototype.getReady = function (params) {
    this.gridSize = params.resolution;
  };

  Controller.prototype.update = function (updates) {
    var self = this;
    updates.forEach(function (update) {
      if (update.action == 'addNode')
        self.players[update.playerId].addNode (update.pt.x, update.pt.y);
      else if (update.action == 'cutTail')
        self.players[update.playerId].cutTail();
    });
  };


  /**
   * Websocket connection
   */
  var socket = new io.Socket('localhost', {port: 8080, rememberTransport: false});
  socket.connect();

  socket.on ('connect', function () {
    var controller = new Controller (socket);
  });


})();