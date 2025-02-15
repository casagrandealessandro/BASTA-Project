clear all
clc

disp('Server ready, waiting for connections...');
% Create a server listening on desired port
S = tcpserver(12345);

% Specify byte ordering as "Little-Endian" 
% Same setting should be applied to the client side
S.ByteOrder = 'little-endian';

% When something in connection changes execute server function
S.ConnectionChangedFcn = @server_fun;

% Set the timeout to 20s
S.Timeout = 20;

% Set the terminator character to be LineFeed
S.configureTerminator("LF");