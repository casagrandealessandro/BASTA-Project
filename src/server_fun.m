% Function definition. The first parameter is assigned the handle of the 
% TCPserver object that calls the function. The other parameters are 
% neglected (~)
function server_fun(S, ~)
    % Check if the server is connected to the client
    if S.Connected
        disp('Connection OK!');
        disp('Connected with Client with IP: ' + S.ClientAddress ...
            + ' at port number ' + num2str(S.ClientPort));

        % =================================================================


        %% DIFFIE-HELLMAN SYMMETRIC KEY EXCHANGE & IMAGE RECEPTION
        % -----------------------------------------------------------------

        % Read p and g from the client
        p = vpi(char(readline(S)));
        g = vpi(char(readline(S)));

        % Generate server's private random key
        server_private_key = '';
        for k = 1:8
            server_private_key = strcat(server_private_key, ...
                dec2bin(randi([0, 2^32-1], 1, 'uint32'), 32));
        end
        
        % Convert the binary string to a vpi number
        server_private_key = bin2vpi(server_private_key);

        % Compute server public key
        server_public_key = vpi_powermod(g,server_private_key,p);

        % Read the client public key from the client
        client_public_key = vpi(char(readline(S)));

        % Send the server public key to the client
        writeline(S, strtrim(num2str(server_public_key)));

        % Compute the shared key
        shared_key = vpi_powermod(client_public_key,server_private_key,p);
        
        % Receive the encrypted image from client
        while(S.NumBytesAvailable == 0)
            pause(5);
        end
        height = read(S,1,'uint32');
        while(S.NumBytesAvailable == 0)
            pause(5);
        end
        img_bytes = uint8(read(S,S.NumBytesAvailable,'uint8'));

        f_encrypted = reshape(img_bytes, height, []);

        % =================================================================


        %% DECRYPTION + WATERMARK CHECK
        % -----------------------------------------------------------------

        % Key conversion from vpi to 32 bytes long uint8 array
        key_bytes = zeros(1, 32, 'uint8');
        for i = 32:-1:1
            key_bytes(i) = double(mod(shared_key, 256));
            shared_key = floor(shared_key / 256);
        end

        % Flatten again for decryption
        img_bytes = f_encrypted(:);
        
        % Compute the same seed as client
        seed = generate_seed(key_bytes);
        
        % Set the random generator with the obtained seed
        rng(seed, 'twister');
        
        % Generate the same random permutation as client
        N = numel(img_bytes);
        perm_indices = randperm(N);

        % Compute the inverse index permutation mapping
        inverse_perm_indices = zeros(1, N);
        inverse_perm_indices(perm_indices) = 1:N;
        
        % Bit plane slicing
        [rows,cols] = size(f_encrypted);
        g = dec2bin(f_encrypted,8);
        g = reshape(g', 8, rows * cols);

        figure("Name","Bit plane slicing - decrypted planes")
        f_decrypted = uint8(zeros(rows, cols));
        for c = 1:7
            x = reshape(g(c,:), rows, cols) - '0';
            % Decryption step: inverse permutation of the pixel
            x_decrypted = x(inverse_perm_indices);
            x_decrypted = reshape(x_decrypted, rows, cols);

            subplot(2,4,c);
            imshow(x_decrypted,[]);
            title("Plane " + c);

            % Rebuild decrypted image
            f_decrypted = f_decrypted + uint8(x_decrypted) .* 2^(8 - c);

            % Generate a new random index sequence
            perm_indices = randperm(N);
            % Compute the new inverse index permutation mapping
            inverse_perm_indices(perm_indices) = 1:N;
        end

        % Watermark extraction and check
        watermark = g(8,:);
        watermark = double(reshape(watermark, rows, cols));
        watermark = double(watermark >= 49);
        
        subplot(2,4,8);
        imshow(watermark,[]);
        title("Plane 8 (watermark)");

        % Original watermark (to check equality)
        imagePath = fullfile('..', 'images', 'watermark.tiff');
        orig_watermark = mat2gray(double(imread(imagePath)));
        orig_watermark = imresize(orig_watermark,size(f_decrypted));
        % Ensure the watermark is binary
        orig_watermark = double(orig_watermark > 0.5);

        % Check if the watermarks are equal
        if isequal(watermark, orig_watermark)
            disp('The watermarks matches');
        else
            disp('The watermarks don''t matches');
        end

        f = figure("Name","Decrypted image");
        ax = axes(f);
        imshow(f_decrypted,[],'Parent',ax);
        title(ax,"Decrypted image");
    else
        disp('Client disconnected');
    end
end