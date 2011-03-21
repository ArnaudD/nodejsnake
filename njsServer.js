
var http = require('http'),
    io = require('socket.io'),

server = http.createServer(function(req, res){
 res.writeHead(200, {'Content-Type': 'text/html'});
 res.end('<h1>Hello from the websocket server !</h1>');
});
server.listen(8080);

// socket.io
var socket = io.listen(server);
socket.on('connection', function(client){

  client.on('message', function(direction){
    client.broadcast(direction);
  });

});