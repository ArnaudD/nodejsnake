
function njSnakeLoad () {
  var libs = [
      'http://localhost:8080/socket.io/socket.io.js',
      'https://ajax.googleapis.com/ajax/libs/jquery/1.5.1/jquery.min.js',
      'http://github.com/DmitryBaranovskiy/raphael/raw/master/raphael-min.js',
      '../njsClient.js'
  ];

  for (i in libs) {
    document.write('<script src="'+libs[i]+'"></script>');
  }


  document.head.innerHTML += '<link rel="stylesheet" type="text/css" href="../njs.css" />';
}

(function() {

  // Detect easter egg combination
  njSnakeLoad(); // TODO

})();

