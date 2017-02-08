var path = require('path');
var express = require('express');
var app = express();
var http = require('http').Server(app);
var io = require('socket.io')(http);
var fs = require('fs');
var logStream = fs.createWriteStream(__dirname + '/access.log', {flags: 'a'});
var cors = require('cors');
var child_process = require('child_process');

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
        // logStream.write(socket.handshake.address + ": " + data.message + "\n");

	console.log('received a message');

        fs.writeFile("../uploads/photo.jpg", new Buffer(data, "base64"), function(err) {	
		child_process.exec('sudo ../shell/./predict.sh ${HOME}/horus/uploads/photo.jpg', function(err, stdout, stderr) {
			if (err) {
				// console.error(err);
				io.emit('server:message', 'Sorry, I could not recognize anything');
			} else {
				if (!err || !stderr) { 
					const regex = /0\)(.*)\s\.\s/g;
					var match = regex.exec(stdout);
					
					if (match) {
						console.log(match[1]);
						io.emit('server:message', match[1]);
					}
				}
				// console.log(stdout);
				// console.log(stderr);
			}
		});
	 });

        // message received from client, now broadcast it to everyone else
	//io.emit('server:message',['Apple for life', '30', '20']);
    })

    socket.on('disconnect', function () {
        console.log(username + ' disconnected');
    });
});



http.listen(8080, function(){
  console.log('listening on *:8080');
});
