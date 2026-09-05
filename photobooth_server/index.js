const express = require('express');
const http = require('http');
const { Server } = require("socket.io");

const app = express();
const server = http.createServer(app);
const io = new Server(server);

let connectedClients = [];
let readyCount = 0;

io.on('connection', (socket) => {
    // Reject connections if two clients are already connected.
    if (connectedClients.length >= 2) {
        console.log('Connection rejected: A session is already in progress.');
        socket.disconnect(true);
        return;
    }

    connectedClients.push(socket);
    console.log(`A user connected. Total users: ${connectedClients.length}`);

    // Assign roles: The first user is the 'host', the second is the 'guest'.
    if (connectedClients.length === 1) {
        socket.emit('user-role', { role: 'host' });
        console.log(`Socket ${socket.id} assigned role: host`);
    } else if (connectedClients.length === 2) {
        socket.emit('user-role', { role: 'guest' });
        console.log(`Socket ${socket.id} assigned role: guest`);
        // Notify the host that the guest has joined
        const hostSocket = connectedClients.find(s => s.id !== socket.id);
        if(hostSocket) {
            hostSocket.emit('guest-joined');
        }
    }

    // Relay WebRTC signaling messages
    socket.on('offer', (data) => {
        console.log(`Relaying offer from ${socket.id}`);
        const otherClient = connectedClients.find(s => s.id !== socket.id);
        if (otherClient) {
            otherClient.emit('offer', data);
        }
    });

    socket.on('answer', (data) => {
        console.log(`Relaying answer from ${socket.id}`);
        const otherClient = connectedClients.find(s => s.id !== socket.id);
        if (otherClient) {
            otherClient.emit('answer', data);
        }
    });

    socket.on('ice-candidate', (data) => {
        console.log(`Relaying ICE candidate from ${socket.id}`);
        const otherClient = connectedClients.find(s => s.id !== socket.id);
        if (otherClient) {
            otherClient.emit('ice-candidate', data);
        }
    });

    // Handle the synchronized ready state
    socket.on('user-ready', () => {
        readyCount++;
        console.log(`User is ready. Total ready: ${readyCount}`);
        if (readyCount === 2) {
            console.log('Both users are ready. Starting countdown.');
            io.emit('start-countdown');
            readyCount = 0; // Reset for the next round
        }
    });

    // Handle disconnection
    socket.on('disconnect', () => {
        console.log(`User disconnected: ${socket.id}`);
        connectedClients = connectedClients.filter(s => s.id !== socket.id);
        // If a user disconnects, reset the ready count.
        if (connectedClients.length < 2) {
            readyCount = 0; 
        }
        // Notify the other user about the disconnection
        const otherClient = connectedClients.find(s => s.id !== socket.id);
        if(otherClient) {
            otherClient.emit('partner-disconnected');
        }
        console.log(`Total users: ${connectedClients.length}`);
    });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`Signaling server running on port ${PORT}`);
});
