
(function() {

  var DIR_LEFT  = 37;
  var DIR_UP    = 38;
  var DIR_RIGHT = 39;
  var DIR_DOWN  = 40;

  var nodeSize   = 10; // Size (in px) of one snake node
  var gridHeight, gridWidth; // Size of the grid (in node)
  var speed = 100;

  var paper;

  /**
   * Snake class
   * @param paper
   */
  function Snake (paper) {

    this.nodes = []; // Raphael nodes
    this.size = 50;
    this.paper = paper; 
    this.direction = DIR_UP;
    this.previousDirection = DIR_UP;

  }

  Snake.prototype.drawNode = function (x,y) {

    var rect = this.paper.rect((x * 11) + 1, (y * 11) + 1, nodeSize, nodeSize).attr({
      fill: '#0F0',
      stroke: 'none'
    }).animate ({fill: '#FFF'}, speed * this.size);
    this.nodes.push ({x: x, y: y, r: rect});
  };

  Snake.prototype.cutTail = function () {

    var deletedNode = this.nodes.shift().r;
    deletedNode.animate({opacity: 0}, speed, function () {
      this.remove();
    });
    
  };

  Snake.prototype.move = function () {

    // Compute next node coordinate
    var x = this.nodes[this.nodes.length - 1].x ;
    var y = this.nodes[this.nodes.length - 1].y ;
    switch (this.direction) {
      case DIR_DOWN:  y++; break;
      case DIR_UP:    y--; break;
      case DIR_RIGHT: x++; break;
      case DIR_LEFT:  x--; break;
    }

    this.drawNode(x,y);

    // If the snake hasn't reached it's size yet, don't delete its tail.
    if (this.nodes.length > this.size) {
      this.cutTail();
    }
  };



  // Init Canvas
  paper = Raphael(0, 0, document.width, document.height);
  paper.canvas.id = 'njsGrid';

  gridHeight = document.height / (nodeSize + 1);
  gridWidth  = document.width / (nodeSize + 1);



  var snake = new Snake (paper);
  snake.drawNode(gridWidth / 2, gridHeight/2);



  var socket = new io.Socket('localhost', {port: 8080, rememberTransport: false});
  socket.connect();
  socket.on('message', function(obj){
    snake.direction = parseInt(obj);
  });

  $('body').keydown (function (e) {
    snake.direction = e.which;
    socket.send(e.which);
  });

  function mainLoop ()
  {
    snake.move();
    setTimeout(mainLoop, speed);
  }

  mainLoop();

})();