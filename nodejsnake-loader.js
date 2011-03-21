
function njSnakeLoad () {
  var libs = [
      'https://ajax.googleapis.com/ajax/libs/jquery/1.5.1/jquery.min.js',
      'http://github.com/DmitryBaranovskiy/raphael/raw/master/raphael-min.js',
      '../nodejsnake.js'
  ];

  for (i in libs) {
    document.write('<script src="'+libs[i]+'"></script>');
  }


  document.head.innerHTML += '<link rel="stylesheet" type="text/css" href="../nodejsnake.css" />';
}

(function() {

  // Detect easter egg combination
  njSnakeLoad(); // TODO

})();

