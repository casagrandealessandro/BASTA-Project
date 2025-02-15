function C = client_connection(ip,port)

    connectionSuccessful = 0;
    % Connection error handling in case of multiple clients insisting on
    % the same server (necessary due to MATLAB's inability to handle
    % parallel threads  
    %
    % Keep trying until success
    while connectionSuccessful == 0
        try
            C = tcpclient(ip,port);
            connectionSuccessful = 1;
            % If connection to server fails, the instructions following
            % "catch ME" are executed
        catch ME    
            % Check the type of error
            if strcmp(ME.identifier, 'MATLAB:networklib:tcpclient:cannotCreateObject')
                connectionSuccessful = 0;
                disp('wait: server not ready yet')
            end
        end
    end
    
    % Configure terminator character to Carriage Return
    configureTerminator(C,"CR");

    % Specify byte ordering as "Little-Endian" 
    % Same setting should be applied to the server side
    C.ByteOrder = 'little-endian';

    % Set the timeout to 20s
    C.Timeout = 20;

    % Set the terminator character to be LineFeed
    C.configureTerminator("LF");
end