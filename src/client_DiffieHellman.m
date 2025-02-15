function shared_key = client_DiffieHellman(C)
    % Prime number of 256 bits
    p = vpi('71745965361813286888290738371340143647569517349847539868037209325440031032373');
    % Generator
    g = vpi(2);

    % Send to server p and g
    writeline(C, strtrim(num2str(p)));
    writeline(C, strtrim(num2str(g)));
    
    % Client's private random key
    client_private_key = '';
    for k = 1:8
        client_private_key = strcat(client_private_key, ...
            dec2bin(randi([0, 2^32-1], 1, 'uint32'), 32));
    end

    % Convert the binary string to a vpi number
    client_private_key = bin2vpi(client_private_key);

    % Computes client public key
    client_public_key = vpi_powermod(g,client_private_key,p);
    
    % Sends to server the client public key
    writeline(C, strtrim(num2str(client_public_key)));

    % Gets server public key
    server_public_key = vpi(char(readline(C)));
    
    % Computes shared key
    shared_key = vpi_powermod(server_public_key,client_private_key,p);
end