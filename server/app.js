var path = require('path');
var express = require('express');
var app = express();
var http = require('http').Server(app);
var io = require('socket.io')(http);
var fs = require('fs');
var logStream = fs.createWriteStream(__dirname + '/access.log', {flags: 'a'});
var cors = require('cors');

cors(app);

app.use(express.static(path.join(__dirname, 'public')));
app.use(express.static(path.join(__dirname, 'static')));

app.get('/*', function(req, res) {
	res.send('Hello!');
});

io.on('connection', function (socket) {
    username = socket.handshake.query.username;
    console.log(username + ' connected from ip:  ' + socket.handshake.address);

    socket.on('client:message', function (data) {
//        console.log(data);

        // logStream.write(socket.handshake.address + ": " + data.message + "\n");
        // fs.writeFile("photo.jpg", new Buffer(data, "base64"), function(err) {});

        // message received from client, now broadcast it to everyone else
	io.emit('server:message',['Apple for life', '30', '20']);
    })

    socket.on('disconnect', function () {
        console.log(username + ' disconnected');
    });
});

http.listen(8080, function(){
  console.log('listening on *:8080');
});
