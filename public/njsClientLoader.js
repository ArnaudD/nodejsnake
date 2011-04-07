

(function() {

  function njSnakeLoad () {
    var libs = [
        'socket.io/socket.io.js',
        'jquery.js',
        'raphael.js',
        'njsClient.js'
    ];

    for (src in libs) {
      document.write('<script src="'+libs[src]+'"></script>');
    }

    document.head.innerHTML += '<link rel="stylesheet" type="text/css" href="njs.css" />';
  }

  // Detect easter egg combination
  njSnakeLoad(); // TODO

})();

