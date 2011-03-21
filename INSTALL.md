

# Install node
    sudo apt-get install g++ curl libssl-dev apache2-utils git-core curl
    git clone https://github.com/joyent/node.git
    cd node
    ./configure
    make
    sudo make install

# Install npm
    curl http://npmjs.org/install.sh | sudo sh

# Install Socket.io
    sudo npm install socket.io 


